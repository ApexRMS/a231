#### a231: QC connectivity analysis
#### Script by Chloé Debyser and Bronwyn Rayfield

#### 1. Filter Protected Areas

############################################################################################################################
# This code:                                                                                                               #
# - Removes aquatic protected areas from AP and RMN datasets                                                               #
# - Produces a vector layer of selected protected areas from the AP dataset only                                           #
# - Produces a vector layer of selected protected areas from the AP and RMN datasets                                       #
############################################################################################################################

#### Workspace ####
# Packages
# devtools::install_github("vlucet/rgrassdoc")
library(rgrass7)
library(rgrassdoc)
library(tidyverse)

# Settings
Sys.setenv(TZ='GMT')
options(stringsAsFactors=FALSE)

# Directories
gisBase <- "C:/Program Files/GRASS GIS 7.4.3"
dataDir <- "Data"
resultsDir <- "Data" # Same as data directory
gisDbase <- "Results/grass7"

# Input parameters
waterThreshold <- 50 # Minimum percentage of the protected area that must fall in water for the area to be considered "aquatic" (and therefore removed from consideration)
bufferThreshold <- 900 # Protected areas must be at least this size (in ha) to be retained within the buffer
studyAreaThreshold <- 150 # Protected areas must be at least this size (in ha) to be retained within the study area

# Spatial data - Names
      # Study Area
studyArea_shp_Name <- file.path(dataDir, "studyArea_30m_polygon.shp")
studyArea_tif_Name <- file.path(dataDir, "studyarea_30m.tif")
      
      # Protected Areas
AP_Name <- file.path(paste0(dataDir, "/registre_aires_prot"), "AP_REG_S.shp")
RMN_Name <- file.path(paste0(dataDir, "/RMN"), "/RMN.shp")

      # Land cover
landCover_Name <- file.path(dataDir, "landcover_30m.tif")

# Function - Get GRASS vector attribute table
v.get.att <- function(vector_name, sep){
  # Get attributes
  att <- execGRASS("v.db.select", map=vector_name, separator=sep, intern=T)
  
  # Format as dataframe
  tc <- textConnection(att)
  df <- read.table(tc, header = TRUE, sep=sep)
  close(tc)
  
  # Return resulting dataframe
  return(df)
}

#### Set up GRASS Mapset #####
# Create location and PERMANENT mapset
initGRASS(gisBase=gisBase, gisDbase=gisDbase, location='a231', mapset='PERMANENT', override=TRUE)

# Set projection info
execGRASS("g.proj", georef=studyArea_tif_Name, flags="c")

# Initialize new mapset inheriting projection info
execGRASS("g.mapset", mapset = "FilterProtectedAreas", flags="c")

# Import data
execGRASS("v.in.ogr", input=studyArea_shp_Name, output="rawData_vStudyArea", flags=c("overwrite"))
execGRASS('r.in.gdal', input=studyArea_tif_Name, output='rawData_rStudyArea', flags=c("overwrite"))
execGRASS("v.in.ogr", input=AP_Name, output="rawData_AP", snap=30, flags=c("overwrite"))
execGRASS("v.in.ogr", input=RMN_Name, output="rawData_RMN", snap=30, flags=c("overwrite"))
execGRASS('r.in.gdal', input=landCover_Name, output='rawData_landCover', flags=c("overwrite"))

# Set region to all of Quebec
execGRASS('g.region', vector='rawData_AP')

#### Remove aquatic protected areas ####
# AP
execGRASS('v.extract', input='rawData_AP', where="NOT DESIGNOM LIKE 'Aire de concentration d''oiseaux aquatiques' AND NOT DESIGNOM LIKE 'Parc marin' AND NOT DESIGNOM LIKE 'Habitat du rat musqu%' AND NOT DESIGNOM LIKE '%(aire de nidification et bande de protection 0-200 m)'", output='AP_terrestrial', 'overwrite')

# RMN
      # Create a layer of water only
execGRASS('g.copy', raster=c('rawData_landCover', 'water'))
execGRASS('r.null', map='water', setnull='0-699')
execGRASS('r.null', map='water', setnull='701-1000')

      # Count number of water cells within each protected area
execGRASS('v.rast.stats', map='rawData_RMN', raster='water', column_prefix='water', method='sum')
execGRASS('v.db.addcolumn', map='rawData_RMN', columns='water_number integer')
execGRASS('v.db.update', map='rawData_RMN', column='water_number', query_column = 'water_sum / 700')

      # Count total number of cells within each protected area
execGRASS('v.rast.stats', map='rawData_RMN', raster='rawData_landCover', column_prefix='total', method='number')

      # Calculate percentage of protected area that falls in water
execGRASS('v.db.addcolumn', map='rawData_RMN', columns='water_percentage double')
execGRASS('v.db.update', map='rawData_RMN', column='water_percentage', query_column = '100 * water_number / total_number')
execGRASS('v.db.update', map='rawData_RMN', column='water_percentage', value='0', where='water_number IS NULL')
          
      # Remove RMN protected areas that fall in water
execGRASS('v.extract', input='rawData_RMN', where=paste('water_percentage <', waterThreshold), output='RMN_terrestrial', 'overwrite')

#### Merge polygons ####
# AP
      # Create a merge ID column with the same value for all polygons
execGRASS('v.db.addcolumn', map='AP_terrestrial', columns='mergeID integer')
execGRASS('v.db.update', map='AP_terrestrial', column='mergeID', value='1')

      # Dissolve on merge ID column
execGRASS('v.dissolve', input='AP_terrestrial', column='mergeID', output='AP_merged', 'overwrite')

      # Multipart to singlepart
execGRASS('v.category', input='AP_merged', output='AP_inter', option='del', cat=-1)
execGRASS('v.category', input='AP_inter', output='AP_merged', option='add', step=1, 'overwrite')

# RMN
      # Create a merge ID column with the same value for all polygons
execGRASS('v.db.addcolumn', map='RMN_terrestrial', columns='mergeID integer')
execGRASS('v.db.update', map='RMN_terrestrial', column='mergeID', value='1')

      # Dissolve on merge ID column
execGRASS('v.dissolve', input='RMN_terrestrial', column='mergeID', output='RMN_merged', 'overwrite')

      # Multipart to singlepart
execGRASS('v.category', input='RMN_merged', output='RMN_inter', option='del', cat=-1)
execGRASS('v.category', input='RMN_inter', output='RMN_merged', option='add', step=1, 'overwrite')

#### Produce Protected Area layer #1: AP areas only ####
# Calculate area of new polygons
execGRASS('v.db.addtable', map='AP_merged')
execGRASS('v.db.addcolumn', map='AP_merged', columns='area_ha double')
execGRASS('v.to.db', map='AP_merged', option='area', columns='area_ha', units='hectares')

# Remove polygons that are not of interest
      # Set NULL areas in study area to zero
execGRASS('r.null', map='rawData_rStudyArea', null=0)

      # Polygons that are fully outside of the buffer
            # Calculate number of cells within the buffer, for each polygon
execGRASS('v.rast.stats', map='AP_merged', raster='rawData_rStudyArea', column_prefix='buffer', method='number')

            # Retain polygons that have at least one cell within the buffer
execGRASS('v.extract', input='AP_merged', where='buffer_number > 0', output='AP_buffer', 'overwrite')

      # Polygons that are smaller than the studyAreaThreshold
execGRASS('v.extract', input='AP_buffer', where=paste('area_ha >=', studyAreaThreshold), output='AP_inter', 'overwrite')

      # Polygons touching the buffer but outside the study area that are smaller than the bufferThreshold
            # Count, for each polygon, the number of cells within the study area
execGRASS('v.rast.stats', map='AP_inter', raster='rawData_rStudyArea', column_prefix='studyArea', method='sum')

            # Convert to area
execGRASS('v.db.addcolumn', map='AP_inter', columns='studyArea_ha double')
execGRASS('v.db.update', map='AP_inter', column='studyArea_ha', query_column='studyArea_sum * 900/10000')

            # Retain polygons that have more than the studyAreaThreshold within the study area OR their total area >= bufferThreshold
execGRASS('v.extract', input='AP_inter', where=paste0('(studyArea_ha >= ', studyAreaThreshold, ') OR (area_ha >= ', bufferThreshold, ')'), output='AP_final', 'overwrite')

      # Format columns
execGRASS('v.db.addcolumn', map='AP_final', columns='studyArea integer')
execGRASS('v.db.update', map='AP_final', column='studyArea', value='0', where=paste0('studyArea_ha < ', studyAreaThreshold))
execGRASS('v.db.update', map='AP_final', column='studyArea', value='1', where=paste0('studyArea_ha >= ', studyAreaThreshold))

      # Drop unnecessary columns
execGRASS('v.db.dropcolumn', map='AP_final', columns='buffer_number')
execGRASS('v.db.dropcolumn', map='AP_final', columns='studyArea_sum')
execGRASS('v.db.dropcolumn', map='AP_final', columns='studyArea_ha')

      # Remove intermediate products
execGRASS('g.remove', type='vector', name='AP_inter', 'f')

# Crop to region
      # Set region to that of buffer
execGRASS('g.region', raster='rawData_rStudyArea')

      # Create vector of region extent
execGRASS('v.in.region', output='region')

      # Crop to region
execGRASS('v.overlay', ainput='AP_final', binput='region', operator='and', output='AP', 'overwrite')

# Format output
execGRASS('v.reclass', input='AP', output='AP_inter', column='a_cat', 'overwrite')
execGRASS('v.db.addtable', map='AP_inter')
execGRASS('v.db.join', map='AP_inter', column='cat', other_table='AP', other_column="a_cat", subset_columns=c('a_area_ha', 'a_studyArea'))
execGRASS('v.db.renamecolumn', map='AP_inter', column=c('a_area_ha', 'area_ha'))
execGRASS('v.db.renamecolumn', map='AP_inter', column=c('a_studyArea', 'studyArea'))

# Remove intermediate products
execGRASS('g.rename', vector=c('AP_inter', 'AP_final'), 'overwrite')
execGRASS('g.remove', type='vector', name='AP', 'f')

# Save
      # Save csv of # of patches
nPatches <- v.get.att('AP_final', "@") %>%
  nrow(.) %>%
  as.data.frame()
colnames(nPatches) <- "NumberOfPatches"
write.csv(nPatches, "Corridors/Results/NPatches_AP.csv", row.names = F)

      # Save shapefile
execGRASS('v.out.ogr', input='AP_final', output='Corridors/Results/ProtectedAreas_AP.shp', format='ESRI_Shapefile', flags=c('m', 'overwrite'))

#### Produce Protected Area layer #2: AP and RMN areas ####
# Set region to all of Quebec again
execGRASS('g.region', vector='rawData_AP')

# Create layer with both AP and RMN areas
execGRASS('v.overlay', ainput='AP_merged', binput='RMN_merged', output='all_terrestrial', operator='or', flags=c('overwrite'))

# Export and re-import with topology cleaning
execGRASS('v.out.ogr', input='all_terrestrial', output='Corridors/Temp.shp', format='ESRI_Shapefile', 'overwrite')
execGRASS("v.in.ogr", input='Corridors/Temp.shp', output="all_terrestrial_clean", snap=30, flags=c("overwrite"))
unlink('Corridors/Temp.shp')
unlink('Corridors/Temp.dbf')
unlink('Corridors/Temp.prj')
unlink('Corridors/Temp.shx')

# Merge all overlapping and adjacent areas
      # Create a merge ID column with the same value for all polygons
execGRASS('v.db.addtable', map='all_terrestrial_clean')
execGRASS('v.db.addcolumn', map='all_terrestrial_clean', columns='mergeID integer')
execGRASS('v.db.update', map='all_terrestrial_clean', column='mergeID', value='1')

      # Dissolve on merge ID column
execGRASS('v.dissolve', input='all_terrestrial_clean', column='mergeID', output='all_merged', 'overwrite')

      # Multipart to singlepart
execGRASS('v.category', input='all_merged', output='all_inter', option='del', cat=-1)
execGRASS('v.category', input='all_inter', output='all_merged', option='add', step=1, 'overwrite')

# Calculate area of new polygons
execGRASS('v.db.addtable', map='all_merged')
execGRASS('v.db.addcolumn', map='all_merged', columns='area_ha double')
execGRASS('v.to.db', map='all_merged', option='area', columns='area_ha', units='hectares')

# Remove polygons that are not of interest
      # Polygons that are fully outside of the buffer
            # Calculate number of cells within the buffer, for each polygon
execGRASS('v.rast.stats', map='all_merged', raster='rawData_rStudyArea', column_prefix='buffer', method='number')

            # Retain polygons that have at least one cell within the buffer
execGRASS('v.extract', input='all_merged', where='buffer_number > 0', output='all_buffer', 'overwrite')

      # Polygons that are smaller than the studyAreaThreshold
execGRASS('v.extract', input='all_buffer', where=paste('area_ha >=', studyAreaThreshold), output='all_inter', 'overwrite')

      # Polygons touching the buffer but outside the study area that are smaller than the bufferThreshold
            # Count, for each polygon, the number of cells within the study area
execGRASS('v.rast.stats', map='all_inter', raster='rawData_rStudyArea', column_prefix='studyArea', method='sum')

            # Convert to area
execGRASS('v.db.addcolumn', map='all_inter', columns='studyArea_ha double')
execGRASS('v.db.update', map='all_inter', column='studyArea_ha', query_column='studyArea_sum * 900/10000')

            # Retain polygons that have more than the studyAreaThreshold within the study area OR their total area >= bufferThreshold
execGRASS('v.extract', input='all_inter', where=paste0('(studyArea_ha >= ', studyAreaThreshold, ') OR (area_ha >= ', bufferThreshold, ')'), output='all_final', 'overwrite')

      # Format columns
execGRASS('v.db.addcolumn', map='all_final', columns='studyArea integer')
execGRASS('v.db.update', map='all_final', column='studyArea', value='0', where=paste0('studyArea_ha < ', studyAreaThreshold))
execGRASS('v.db.update', map='all_final', column='studyArea', value='1', where=paste0('studyArea_ha >= ', studyAreaThreshold))

      # Drop unnecessary columns
execGRASS('v.db.dropcolumn', map='all_final', columns='buffer_number')
execGRASS('v.db.dropcolumn', map='all_final', columns='studyArea_sum')
execGRASS('v.db.dropcolumn', map='all_final', columns='studyArea_ha')

      # Remove intermediate products
execGRASS('g.remove', type='vector', name='all_inter', 'f')

# Crop to region
      # Set region to that of buffer
execGRASS('g.region', raster='rawData_rStudyArea')

      # Crop to region
execGRASS('v.overlay', ainput='all_final', binput='region', operator='and', output='all1', 'overwrite')

# Format output
execGRASS('v.reclass', input='all1', output='all_inter', column='a_cat', 'overwrite')
execGRASS('v.db.addtable', map='all_inter')
execGRASS('v.db.join', map='all_inter', column='cat', other_table='all1', other_column="a_cat", subset_columns=c('a_area_ha', 'a_studyArea'))
execGRASS('v.db.renamecolumn', map='all_inter', column=c('a_area_ha', 'area_ha'))
execGRASS('v.db.renamecolumn', map='all_inter', column=c('a_studyArea', 'studyArea'))

# Remove intermediate products
execGRASS('g.rename', vector=c('all_inter', 'all_final'), 'overwrite')
execGRASS('g.remove', type='vector', name='all1', 'f')

# Save
      # Save csv of # of patches
nPatches <- v.get.att('all_final', "@") %>%
  nrow(.) %>%
  as.data.frame()
colnames(nPatches) <- "NumberOfPatches"
write.csv(nPatches, file.path(resultsDir, "NPatches_APandRMN_multipart.csv"), row.names = F)

      # Save shapefile
execGRASS('v.out.ogr', input='all_final', output=file.path(resultsDir, 'ProtectedAreas_APandRMN_multipart.shp'), format='ESRI_Shapefile', flags=c('m', 'overwrite'))

# Multipart to singlepart
execGRASS('v.category', input='all_final', output='all_final_singlepart_inter', option='del', cat=-1)
execGRASS('v.category', input='all_final_singlepart_inter', output='all_final_singlepart', option='add', step=1, 'overwrite')
execGRASS('g.remove', type='vector', name='all_final_singlepart_inter', 'f')

# Save shapefile
execGRASS('v.out.ogr', input='all_final_singlepart', output=file.path(resultsDir, 'ProtectedAreas_APandRMN_singlepart.shp'), format='ESRI_Shapefile', flags=c('m', 'overwrite'))


# Crop to within BTSL
execGRASS('v.overlay', ainput='all_final', binput='rawData_vStudyArea', operator='and', output='all_final_btsl', 'overwrite')

# Save shapefile
execGRASS('v.out.ogr', input='all_final_btsl', output=file.path(resultsDir, 'ProtectedAreas_APandRMN_multipart_btsl.shp'), format='ESRI_Shapefile', flags=c('m', 'overwrite'))
