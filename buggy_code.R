# renv::init()
# pkg_list = c('terra', 'geodata', 'ggplot2', 'tidyterra', 'rnaturalearth', 
#              'RColorBrewer', 'devtools')
# install.packages(pkg_list)
# devtools::install_github("ropensci/rnaturalearthhires")

# Setup -------------------------------------------------------------------
library(RColorBrewer)
library(terra)
library(geodata)
library(ggplot2)
library(tidyterra)
library(rnaturalearth)



# Functions ---------------------------------------------------------------

resample_combine = function(template, to_resample) {
  #resample global layers to CA and to match climate model resolution
  
  #resample list
  resampled = lapply(to_resample, resample, y=template)
  
  resampled[[length(to_resample)+1]] = template #add template layer
  
  all_layers = rast(resampled) #turn into one object
  
  #project to good crs for california
  all_layers = project(all_layers, crs("ESRI:102008"))
  
  return(all_layers)
  
}


#convert breaks to a list of labels where only the multiples of n are displayed
scale_labels = function(n=5) {
  lab_fun = function(x) sapply(x, function(x) if (x %% n == 0) paste0(x) else '')
  
  return(lab_fun)
}

#labeling function to convert raster layer names to season names
x_to_season = function(x) {
  seasons = c('Winter', 'Spring', 'Summer', 'Fall') #list of seasons
  
  #remove text from layer names and convert to numbers
  id = as.numeric(gsub('[^0-9]', '', x))
  
  return(seasons[id])
  
}

#convert function to labeller class
x_to_season_lab = as_labeller(x_to_season)

# Get Data ----------------------------------------------------------------

geodata_path('./data')

#global precipitation data from worldclim
#you can download by country but the resolution is forced to be 0.5
prec = cmip6_world(model='ACCESS-CM2', ssp='585', time='2061-2080', var='prec', res=5)
names(prec) = month.name

crops = cropland('worldcover')

built = landcover('built')

human = footprint()

#outlines of US States
usa_sf = ne_states(iso_a2 = 'us', returnclass = 'sf')
usa = vect(usa_sf)

#R logo
logo_fn = rast(system.file("ex/logo.tif", package="terra"))
logo = rast(logo_fn) 


#blue color palette function for plotting
blues = colorRampPalette(brewer.pal(9, 'Blues'))


# Filtering ---------------------------------------------------------------

not_contiguous = c('Alaska', 'Hawaii') 
voi = c('name', 'type', 'region', 'postal')

#removing extraneous data for easier plotting
c_usa = usa[which(!usa$name %in% not_contiguous), voi]

ca = usa[which(usa$name == 'California'), voi]


# Human Precipitation in CA -----------------------------------------------

prec_ca = crop(prec, ca)

human_impact = list(crops, built, human)

human_ca = resample_combine(prec_ca, human_impact)


# Spatial comparison ------------------------------------------------------

#convert raster to lon/lat to match USA data
logo_ll = project(logo, crs(usa))

#convert raster to polygons so we can use rgeos functionality
logo_sp = as.polygons(logo_ll)

#ask whether the R logo intersects 
if (any(is.related(logo_sp, usa, relation='intersects'))) {
  print('The R logo is in the United States!')
} else {
  print('The R logo is not in the United States')
}


# Area calculation --------------------------------------------------------

#get the area of each layer
logo_area_layers = expanse(logo_ll)

#get the area of the first layer
logo_area = logo_area_layers[logo_area_layers==1, 'area']

# get area of polygons
usa_area = sum(expanse(usa))

if (usa_area > logo_area) {
  print('The contiguous United States is bigger than the R logo.')
} else {
  print('The R logo is bigger than the contiguous United States!')
}




# Precipitation Seasonality in the United States --------------------------

albers_NA = crs("ESRI:102008")

nlyr(prec) #data is monthly

range(values(prec), na.rm=TRUE) #data is likely in mm

#crop precip data to contiguous us extent and then mask it to create the correct shape
prec_usa = mask(crop(prec, c_usa), c_usa)

#project precip to albers projection
prec_albers = project(prec_usa, albers_NA)

#convert mm to inches
prec_in = prec_albers*0.0393701

#calculate Seasonality (coefficient of variation for each cell)
seasonality = app(prec_in, fun=function(x) 100*sd(x, na.rm=TRUE)/mean(x, na.rm=TRUE))

#project contiguous usa polygons
usa_albers = project(c_usa, albers_NA)

#plot seasonality with state outlines
par(mfrow=c(1,1))
plot(seasonality, axes=FALSE, col=blues(120),
     main='Precipitation Seasonality\n(coefficient of variation)')
polys(usa_albers)



# Investigate Precipitation Throughout the Seasons ------------------------

#index to group months by quarter
quarters = c(1, 1, rep(2:4, each=3), 1)

#sum by quarter
prec_q = tapp(prec_in, index=quarters, fun=sum)

max_val = 30

#set values greater than 30 to be 30 so we can plot on the same scale
prec_q_30 = classify(prec_q, matrix(c(max_val, 100, max_val), nrow=1))

#creating a copy of polygons for each quarter
usa_lyr = merge(usa_albers, data.frame(lyr=names(prec_q_30)))

# list of breaks in precip values for plotting
scale_breaks = seq(0, max_val, by=0.5)

p <- ggplot() + #initialize plot
  geom_spatraster(data=prec_q_30) + #add precip raster
  geom_spatvector(data=usa_lyr, fill=NA) + #add polygons, fill with nothing
  facet_wrap(~lyr, labeller=x_to_season_lab) + #facet wrap by layer
  labs(title='Quarterly Precipitation in the Contiguous United States') +
  
  #create binned color scheme with appropriate breaks and labels
  scale_fill_stepsn(breaks=scale_breaks, colors=blues(length(scale_breaks)), 
                    labels=scale_labels(n=5), name='Precip (in)', na.value=NA) +
  
  theme_bw(25) + #set text size
  theme(axis.text=element_blank(), #remove background lines/ticks/text
        axis.ticks=element_blank(),
        panel.grid = element_blank(),
        legend.text = element_text(size=17),
        legend.key.size = unit(1.6, 'cm')) 

p
# Averaging by State ------------------------------------------------------

#extract average precip by month for each state
usa_precip = extract(prec_in, usa_albers, fun=mean, ID=FALSE, bind=TRUE, na.rm=TRUE)

#bins for monthly precip
month_breaks = seq(0, 7.5, by=0.5)

#plot monthly precipitation averages using terra functionality
plot(usa_precip, y=month.name, breaks=month_breaks, col=blues(length(month_breaks)))



# Using ggplot ------------------------------------------------------------

require(sf)

usa_precip_long = st_as_sf(usa_precip) %>% #convert to simple features
  #convert to long
  tidyr::pivot_longer(cols = tidyselect::all_of(month.name), names_to = 'month',
                      values_to = 'precip')

#reorder factor levels
usa_precip_long$month = factor(usa_precip_long$month, levels=month.name)

#plot using ggplot
pp = ggplot(data=usa_precip_long) + 
  geom_sf(aes(fill=precip)) +
  facet_wrap(~month) +
  labs(title='Monthly Precipitation in the Contiguous United States') +
  
  #create binned color scheme with appropriate breaks and labels
  scale_fill_stepsn(breaks=month_breaks, colors=blues(length(month_breaks)), 
                    labels=scale_labels(n=2), name='Precip (in)', na.value=NA) +
  theme_bw(20) + #set text size
  theme(axis.text=element_blank(), #remove background lines/ticks/text
        axis.ticks=element_blank(),
        panel.grid = element_blank(),
        legend.text = element_text(size=17),
        legend.key.size = unit(1.6, 'cm')) 


pp

