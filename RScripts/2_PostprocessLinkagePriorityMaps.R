#### a231: QC connectivity analysis
#### Script by Bronwyn Rayfield

#### 2. Post-process Linkage Priority Maps

#######################################################################################
# This code:                                                                          #
# - Clips each species linkage priority map to the BTSL and rescales it 0 - 1         #
# - Produces a summary linkage priority map for BTSL + buffer                         #
# - Produces a summary linkage priority map for BTSL alone                            #
#######################################################################################

# Workspace
library(raster)

# Directories
dataDir <- "Data"
resultDir <- "Results"

# List of species to process
speciesList <- c("BLBR", "PLCI", "MAAM", "RANA", "URAM")

# BTSL study area delimitation from Phase II
btsl<-raster(file.path(dataDir, "studyArea_30m.tif"))

# Loop over all species to clip and rescale linkage priority maps
for(spp in speciesList){
  # Read in linkage priority with buffer
  m <- raster(file.path(resultDir, "LinkagePriority_Buffer", paste0(spp, "_linkage_priority1.tif")))
  # Clip to BTSL
  m <- m * btsl
  # Rescale 0 -1
  mapMax <- cellStats(m,max)
  mapMin <- cellStats(m,min)
  m01 <- (m-mapMin)/(mapMax-mapMin)
  # Write rasters
  writeRaster(m, file.path(resultDir, paste0(spp, "_btsl_linkage_priority1.tif")), overwrite=TRUE)
  writeRaster(m01, file.path(resultDir, paste0(spp, "_btsl01_linkage_priority1.tif")), overwrite=TRUE)
}


# Combine species rasters into one with buffer
# Read in rasters
BLBR <- raster(file.path(resultDir, "LinkagePriority_Buffer", "BLBR_linkage_priority1.tif"))
PLCI <- raster(file.path(resultDir, "LinkagePriority_Buffer", "PLCI_linkage_priority1.tif"))
MAAM <- raster(file.path(resultDir, "LinkagePriority_Buffer", "MAAM_linkage_priority1.tif"))
RANA <- raster(file.path(resultDir, "LinkagePriority_Buffer", "RANA_linkage_priority1.tif"))
URAM <- raster(file.path(resultDir, "LinkagePriority_Buffer", "URAM_linkage_priority1.tif"))
# Recode NA to 0 before summing
BLBR[Which(is.na(BLBR))]<-0
PLCI[Which(is.na(PLCI))]<-0
MAAM[Which(is.na(MAAM))]<-0
RANA[Which(is.na(RANA))]<-0
URAM[Which(is.na(URAM))]<-0
# Sum all species maps
all <- BLBR + PLCI + RANA + MAAM + URAM
# Write raster
writeRaster(all, file.path(resultDir, "LinkagePriority_Buffer", "ALL_linkage_priority1.tif"), overwrite=TRUE)

# Look at raster value distribution
cellStats(all,max)
# [1] 4.65547
freq(all)
# value    count
# [1,]     0 34041061
# [2,]     1 37586316
# [3,]     2 29294745
# [4,]     3 18734503
# [5,]     4  5809631
# [6,]     5   221972

# Calculate percentiles for map legend
# Remove 0's when calculating percentile cut-off values
allNA <- all
allNA[allNA==0] <- NA
quantile(allNA, probs = c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1))
# 10%       20%       30%       40%       50%       60%       70%       80%       90%      100% 
#   0.4119043 0.7506086 1.0488981 1.2688501 1.5431250 1.8302179 2.2644062 2.6907768 3.2815365 4.6554700 

# Combine species rasters into one within BTSL
# Read in rasters before summing
BLBR <- raster(file.path(resultDir, "BLBR_btsl01_linkage_priority1.tif"))
PLCI <- raster(file.path(resultDir, "PLCI_btsl01_linkage_priority1.tif"))
MAAM <- raster(file.path(resultDir, "MAAM_btsl01_linkage_priority1.tif"))
RANA <- raster(file.path(resultDir, "RANA_btsl01_linkage_priority1.tif"))
URAM <- raster(file.path(resultDir, "URAM_btsl01_linkage_priority1.tif"))
# Recode NA to 0
BLBR[Which(is.na(BLBR))]<-0
PLCI[Which(is.na(PLCI))]<-0
MAAM[Which(is.na(MAAM))]<-0
RANA[Which(is.na(RANA))]<-0
URAM[Which(is.na(URAM))]<-0
# Sum all species maps
all_btsl01 <- BLBR + PLCI + RANA + MAAM + URAM
# Write raster
writeRaster(all_btsl01, file.path(resultDir, "ALL_btsl01_linkage_priority1.tif"), overwrite=TRUE)

# Look at raster value distribution
cellStats(all_btsl01,max)
# [1] 4.365118
freq(all_btsl01)
# value     count
# [1,]     0 104380278
# [2,]     1  11803445
# [3,]     2   6884443
# [4,]     3   2520001
# [5,]     4    100061

# Calculate percentiles for map legend
# Remove 0's when calculating percentile cut-off values
all_btsl01NA <- all_btsl01
all_btsl01NA[all_btsl01NA==0] <- NA
quantile(all_btsl01NA, probs = c(0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1))
# 10%       20%       30%       40%       50%       60%       70%       80%       90%      100% 
#   0.2325916 0.4686371 0.7558046 0.9877492 1.1783455 1.3897521 1.6214434 2.0227886 2.4847785 4.3651183
