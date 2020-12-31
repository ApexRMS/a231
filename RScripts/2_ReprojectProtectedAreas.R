#### a224: BTSL Connectivity Phase III
#### Script by Chloé Debyser and Bronwyn Rayfield

#### 2. Rasterize protected areas

############################################################################################################################
# This code:                                                                                                               #
# - Reprojects protected area layers to the A224 CRS                                                                       #
# - Rasterizes the protected area layers and saves them to the results folder                                              #
############################################################################################################################

#### Workspace ####
# Packages
library(rgrass7)
library(rgrassdoc)
library(tidyverse)

# Settings
Sys.setenv(TZ='GMT')
options(stringsAsFactors=FALSE)

# Directories
gisBase <- "C:/Program Files/GRASS GIS 7.4.3"
projectDir <- "F:/ConnectBTSL/Corridors"
dataDir <- paste0(projectDir, "/Data")
resultsDir <- paste0(projectDir, "/Results")
gisDbase <- paste0(resultsDir, "/grass7")

# Spatial data - Names
primaryStratum_Name <- file.path(dataDir, "PrimaryStatum.tif")

#### Set up GRASS Mapset #####
# Create location and PERMANENT mapset
initGRASS(gisBase=gisBase, gisDbase=gisDbase, location='a224', mapset='PERMANENT', override=TRUE)

# Set projection info
execGRASS("g.proj", georef=primaryStratum_Name, flags="c")

# Initialize new mapset inheriting projection info
execGRASS("g.mapset", mapset = "RasterizeProtectedAreas", flags="c")

# Import data
execGRASS('r.in.gdal', input=primaryStratum_Name, output='primaryStratum', flags=c("overwrite"))
execGRASS('v.proj', location='a231', mapset='FilterProtectedAreas', input='rawData_AP', output='AP')
execGRASS('v.proj', location='a231', mapset='FilterProtectedAreas', input='rawData_RMN', output='RMN')

# Set region
execGRASS('g.region', raster='primaryStratum')

#### Rasterize protected area layers ####
# Rasterize
execGRASS('v.to.rast', input='AP', output='AP_raster', use='val', value=1, 'overwrite')
execGRASS('v.to.rast', input='RMN', output='RMN_raster', use='val', value=1, 'overwrite')

# Save
execGRASS('r.out.gdal', input='AP_raster', output=file.path(resultsDir, 'PhaseIII_ProtectedAreas_AP.tif'))
execGRASS('r.out.gdal', input='RMN_raster', output=file.path(resultsDir, 'PhaseIII_ProtectedAreas_RMN.tif'))
