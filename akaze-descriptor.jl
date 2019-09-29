################################################################
# This method  computes the set of descriptors through the nonlinear scale space
function Compute_Descriptors(akaze, kpts)

    t1 = time_ns()

    ## Allocate memory for the matrix with the descriptors
    ## We use the full length binary descriptor -> 486 bits
    t = if (options_.descriptor_size != 0)
        akaze.options_.descriptor_size
    else
        ## We use the random bit selection length binary descriptor
        (6+36+120)*akaze.options_.descriptor_channels
    end
    desc_len = ceil(t/8.0)
    desc = zeros(UInt8, length(kpts), desc_len)

    if options_.descriptor == MLDB
        Compute_Main_Orientation.([akaze], kpts)
    end

    descriptor_function = if options_.descriptor == MLDB_UPRIGHT
        if options_.descriptor_size == 0
            Get_Upright_MLDB_Full_Descriptor
        else
            Get_Upright_MLDB_Descriptor_Subset
        end
    elseif options_.descriptor == MLDB
        if options_.descriptor_size == 0
            Get_MLDB_Full_Descriptor
        else
            Get_MLDB_Descriptor_Subset
        end
    end

    desc = descriptor_function.([akaze], kpts)

    t2 = time_ns()
    akaze.timing_.descriptor = t2 - t1
    desc
end

mymin(a,b) = ifelse(a<b,a,b)
mymax(a,b) = ifelse(a>b,a,b)

################################################################
function Compute_Main_Orientation(akaze, kpt)

    resX = Vector{Float64}(undef, 109)
    resY = Vector{Float64}(undef, 109)
    Ang = Vector{Float64}(undef, 109)

    ## Get the information from the keypoint
    level = kpt.class_id
    ratio = Float64(1<<akaze.evolution_[level].octave)
    s = round(Int64, 0.5*kpt.size/ratio)
    xf = kpt.pt.x/ratio
    yf = kpt.pt.y/ratio

    idx = 1
    ## Calculate derivatives responses for points within radius of 6*scale
    (limj,limk) = size(akaze.evolution_[level].Lx)
    for i in -6:6
        for j in -6:6
            if i*i + j*j < 36
                iy = mymin(limj, mymax(1, round(Int64, yf + j*s)+1))
                ix = mymin(limk, mymax(1, round(Int64, xf + i*s)+1))

                gweight = gauss25[abs(i)+1, abs(j)+1]
                resX[idx] = gweight * akaze.evolution_[level].Lx[iy, ix]
                resY[idx] = gweight * akaze.evolution_[level].Ly[iy, ix]
                Ang[idx] = mod(atan(resY[idx], resX[idx]), 2π)
                idx += 1
            end
        end
    end

    # for u in 1:109
    #     println("$u $(resX[u]) $(resY[u]) $(Ang[u])")
    # end

    ## Variables for computing the dominant direction
    maxXY = 0.0
    ## Loop slides pi/3 window around feature point
    for ang1 in 0:0.15:2.0*π
        ang2 = if (ang1 + π/3.0 > 2.0*π) ang1 - 5.0 * π/3.0 else ang1 + π/3.0 end
        sumX = 0.0
        sumY = 0.0

        for k in 1:109
            ## Get angle from the x-axis of the sample point
            ang = Ang[k]

            ## Determine whether the point is within the window
            if (ang1 < ang2 && ang1 < ang && ang < ang2)
                sumX += resX[k]
                sumY += resY[k]
            elseif (ang2 < ang1 && ((ang > 0 && ang < ang2) || (ang > ang1 && ang < 2.0*π)))
                sumX += resX[k]
                sumY += resY[k]
            end
        end

        ## if the vector produced from this window is longer than all
        ## previous vectors then this forms the new dominant direction
        if (sumX*sumX + sumY*sumY > maxXY)
            ## store largest orientation
            maxXY = sumX*sumX + sumY*sumY
            kpt.angle = mod(atan(sumY, sumX), 2π)
        end
    end
end


# /* ************************************************************************* */
# void AKAZE::Get_MLDB_Full_Descriptor(const cv::KeyPoint& kpt, unsigned char* desc) const

# const int max_channels = 3
# CV_Assert(options_.descriptor_channels <= max_channels)
# float values[16*max_channels]
# const double size_mult[3] = 1, 2.0/3.0, 1.0/2.0end

# float ratio = (float)(1 << kpt.octave)
# float scale = (float)fRound(0.5f*kpt.size / ratio)
# float xf = kpt.pt.x / ratio
# float yf = kpt.pt.y / ratio
# float co = cos(kpt.angle)
# float si = sin(kpt.angle)
# int pattern_size = options_.descriptor_pattern_size

# int dpos = 0
# for(int lvl = 0; lvl < 3; lvl++)
#     int val_count = (lvl + 2) * (lvl + 2)
#     int sample_step = static_cast<int>(ceil(pattern_size * size_mult[lvl]))
#     MLDB_Fill_Values(values, sample_step, kpt.class_id, xf, yf, co, si, scale)
#     MLDB_Binary_Comparisons(values, desc, val_count, dpos)
# end
# end

# /* ************************************************************************* */
# void AKAZE::Get_Upright_MLDB_Full_Descriptor(const cv::KeyPoint& kpt, unsigned char* desc) const

# const int max_channels = 3
# CV_Assert(options_.descriptor_channels <= max_channels)
# float values[16*max_channels]
# const double size_mult[3] = 1, 2.0/3.0, 1.0/2.0end

# float ratio = (float)(1 << kpt.octave)
# float scale = (float)fRound(0.5f*kpt.size / ratio)
# float xf = kpt.pt.x / ratio
# float yf = kpt.pt.y / ratio
# int pattern_size = options_.descriptor_pattern_size

# int dpos = 0
# for(int lvl = 0; lvl < 3; lvl++)
#     int val_count = (lvl + 2) * (lvl + 2)
#     int sample_step = static_cast<int>(ceil(pattern_size * size_mult[lvl]))
#     MLDB_Fill_Upright_Values(values, sample_step, kpt.class_id, xf, yf, scale)
#     MLDB_Binary_Comparisons(values, desc, val_count, dpos)
# end
# end

# /* ************************************************************************* */
# void AKAZE::MLDB_Fill_Values(float* values, int sample_step, int level,
#                              float xf, float yf, float co, float si, float scale) const

# int pattern_size = options_.descriptor_pattern_size
# int nr_channels = options_.descriptor_channels
# int valpos = 0

# for (int i = -pattern_size; i < pattern_size; i += sample_step)
#     for (int j = -pattern_size; j < pattern_size; j += sample_step)

#         float di = 0.0, dx = 0.0, dy = 0.0
#         int nsamples = 0

#         for (int k = i; k < i + sample_step; k++)
#             for (int l = j; l < j + sample_step; l++)

#                 float sample_y = yf + (l*co*scale + k*si*scale)
#                 float sample_x = xf + (-l*si*scale + k*co*scale)

#                 int y1 = fRound(sample_y)
#                 int x1 = fRound(sample_x)

#                 float ri = *(evolution_[level].Lt.ptr<float>(y1)+x1)
#                 di += ri

#                 if(nr_channels > 1)
#                     float rx = *(evolution_[level].Lx.ptr<float>(y1)+x1)
#                     float ry = *(evolution_[level].Ly.ptr<float>(y1)+x1)
#                     if (nr_channels == 2)
#                         dx += sqrtf(rx*rx + ry*ry)
#                     end
#                 else
#                     float rry = rx*co + ry*si
#                     float rrx = -rx*si + ry*co
#                     dx += rrx
#                     dy += rry
#                 end
#             end
#             nsamples++
#         end
#     end

#     di /= nsamples
#     dx /= nsamples
#     dy /= nsamples

#     values[valpos] = di

#     if (nr_channels > 1)
#         values[valpos + 1] = dx

#         if (nr_channels > 2)
#             values[valpos + 2] = dy

#             valpos += nr_channels
#         end
#     end
# end


# /* ************************************************************************* */
# void AKAZE::MLDB_Fill_Upright_Values(float* values, int sample_step, int level,
#                                      float xf, float yf, float scale) const

# int pattern_size = options_.descriptor_pattern_size
# int nr_channels = options_.descriptor_channels
# int valpos = 0

# for (int i = -pattern_size; i < pattern_size; i += sample_step)
#     for (int j = -pattern_size; j < pattern_size; j += sample_step)

#         float di = 0.0, dx = 0.0, dy = 0.0
#         int nsamples = 0

#         for (int k = i; k < i + sample_step; k++)
#             for (int l = j; l < j + sample_step; l++)

#                 float sample_y = yf + l*scale
#                 float sample_x = xf + k*scale

#                 int y1 = fRound(sample_y)
#                 int x1 = fRound(sample_x)

#                 float ri = *(evolution_[level].Lt.ptr<float>(y1)+x1)
#                 di += ri

#                 if(nr_channels > 1)
#                     float rx = *(evolution_[level].Lx.ptr<float>(y1)+x1)
#                     float ry = *(evolution_[level].Ly.ptr<float>(y1)+x1)
#                     if (nr_channels == 2)
#                         dx += sqrtf(rx*rx + ry*ry)
#                     end
#                 else
#                     dx += rx
#                     dy += ry
#                 end
#             end
#             nsamples++
#         end
#     end

#     di /= nsamples
#     dx /= nsamples
#     dy /= nsamples

#     values[valpos] = di

#     if (nr_channels > 1)
#         values[valpos + 1] = dx

#         if (nr_channels > 2)
#             values[valpos + 2] = dy

#             valpos += nr_channels
#         end
#     end
# end

# /* ************************************************************************* */
# void AKAZE::MLDB_Binary_Comparisons(float* values, unsigned char* desc,
#                                     int count, int& dpos) const

# int nr_channels = options_.descriptor_channels

# for(int pos = 0; pos < nr_channels; pos++)
#     for (int i = 0; i < count; i++)
#         float ival = values[nr_channels * i + pos]
#         for (int j = i + 1; j < count; j++)
#             int res = ival > values[nr_channels * j + pos]
#             desc[dpos >> 3] |= (res << (dpos & 7))
#             dpos++
#         end
#     end
# end
# end

# /* ************************************************************************* */
# void AKAZE::Get_MLDB_Descriptor_Subset(const cv::KeyPoint& kpt, unsigned char* desc)

# float di = 0.f, dx = 0.f, dy = 0.f
# float rx = 0.f, ry = 0.f
# float sample_x = 0.f, sample_y = 0.f
# int x1 = 0, y1 = 0

# ## Get the information from the keypoint
# float ratio = (float)(1<<kpt.octave)
# int scale = fRound(0.5*kpt.size/ratio)
# float angle = kpt.angle
# float level = kpt.class_id
# float yf = kpt.pt.y/ratio
# float xf = kpt.pt.x/ratio
# float co = cos(angle)
# float si = sin(angle)

# ## Allocate memory for the matrix of values
# cv::Mat values = cv::Mat_<float>::zeros((4+9+16)*options_.descriptor_channels, 1)

# ## Sample everything, but only do the comparisons
# vector<int> steps(3)
# steps.at(0) = options_.descriptor_pattern_size
# steps.at(1) = ceil(2.f*options_.descriptor_pattern_size/3.f)
# steps.at(2) = options_.descriptor_pattern_size/2

# for (int i=0; i < descriptorSamples_.rows; i++)
#     int *coords = descriptorSamples_.ptr<int>(i)
#     int sample_step = steps.at(coords[0])
#     di=0.0f
#     dx=0.0f
#     dy=0.0f

#     for (int k = coords[1]; k < coords[1] + sample_step; k++)
#         for (int l = coords[2]; l < coords[2] + sample_step; l++)

#             ## Get the coordinates of the sample point
#             sample_y = yf + (l*scale*co + k*scale*si)
#             sample_x = xf + (-l*scale*si + k*scale*co)

#             y1 = fRound(sample_y)
#             x1 = fRound(sample_x)

#             di += *(evolution_[level].Lt.ptr<float>(y1)+x1)

#             if (options_.descriptor_channels > 1)
#                 rx = *(evolution_[level].Lx.ptr<float>(y1)+x1)
#                 ry = *(evolution_[level].Ly.ptr<float>(y1)+x1)

#                 if (options_.descriptor_channels == 2)
#                     dx += sqrtf(rx*rx + ry*ry)
#                 end
#             else if (options_.descriptor_channels == 3)
#                 ## Get the x and y derivatives on the rotated axis
#                 dx += rx*co + ry*si
#                 dy += -rx*si + ry*co
#             end
#             end
#         end
#     end

#     *(values.ptr<float>(options_.descriptor_channels*i)) = di

#     if (options_.descriptor_channels == 2)
#         *(values.ptr<float>(options_.descriptor_channels*i+1)) = dx
#     else if (options_.descriptor_channels == 3)
#         *(values.ptr<float>(options_.descriptor_channels*i+1)) = dx
#         *(values.ptr<float>(options_.descriptor_channels*i+2)) = dy
#     end
#     end

#     ## Do the comparisons
#     const float *vals = values.ptr<float>(0)
#     const int *comps = descriptorBits_.ptr<int>(0)

#     for (int i=0; i<descriptorBits_.rows; i++)
#         if (vals[comps[2*i]] > vals[comps[2*i +1]])
#             desc[i/8] |= (1<<(i%8))
#         end
#     end
# end

# /* ************************************************************************* */
# void AKAZE::Get_Upright_MLDB_Descriptor_Subset(const cv::KeyPoint& kpt, unsigned char *desc)

# float di = 0.0f, dx = 0.0f, dy = 0.0f
# float rx = 0.0f, ry = 0.0f
# float sample_x = 0.0f, sample_y = 0.0f
# int x1 = 0, y1 = 0

# ## Get the information from the keypoint
# float ratio = (float)(1<<kpt.octave)
# int scale = fRound(0.5*kpt.size/ratio)
# float level = kpt.class_id
# float yf = kpt.pt.y/ratio
# float xf = kpt.pt.x/ratio

# ## Allocate memory for the matrix of values
# cv::Mat values = cv::Mat_<float>::zeros((4+9+16)*options_.descriptor_channels, 1)

# vector<int> steps(3)
# steps.at(0) = options_.descriptor_pattern_size
# steps.at(1) = ceil(2.f*options_.descriptor_pattern_size/3.f)
# steps.at(2) = options_.descriptor_pattern_size/2

# for (int i=0; i < descriptorSamples_.rows; i++)
#     int *coords = descriptorSamples_.ptr<int>(i)
#     int sample_step = steps.at(coords[0])
#     di=0.0f, dx=0.0f, dy=0.0f

#     for (int k = coords[1]; k < coords[1] + sample_step; k++)
#         for (int l = coords[2]; l < coords[2] + sample_step; l++)

#             ## Get the coordinates of the sample point
#             sample_y = yf + l*scale
#             sample_x = xf + k*scale

#             y1 = fRound(sample_y)
#             x1 = fRound(sample_x)
#             di += *(evolution_[level].Lt.ptr<float>(y1)+x1)

#             if (options_.descriptor_channels > 1)
#                 rx = *(evolution_[level].Lx.ptr<float>(y1)+x1)
#                 ry = *(evolution_[level].Ly.ptr<float>(y1)+x1)

#                 if (options_.descriptor_channels == 2)
#                     dx += sqrtf(rx*rx + ry*ry)
#                 end
#             else if (options_.descriptor_channels == 3)
#                 dx += rx
#                 dy += ry
#             end
#             end
#         end
#     end

#     *(values.ptr<float>(options_.descriptor_channels*i)) = di

#     if (options_.descriptor_channels == 2)
#         *(values.ptr<float>(options_.descriptor_channels*i+1)) = dx
#     else if (options_.descriptor_channels == 3)
#         *(values.ptr<float>(options_.descriptor_channels*i+1)) = dx
#         *(values.ptr<float>(options_.descriptor_channels*i+2)) = dy
#     end
#     end

#     ## Do the comparisons
#     const float *vals = values.ptr<float>(0)
#     const int *comps = descriptorBits_.ptr<int>(0)
#     for (int i=0; i<descriptorBits_.rows; i++)
#         if (vals[comps[2*i]] > vals[comps[2*i +1]])
#             desc[i/8] |= (1<<(i%8))
#         end
#     end
# end