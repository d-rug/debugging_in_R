renv::init()
install.packages('terra')

library('terra')

# sessionInfo()

r <- rast(system.file("ex/elev.tif", package="terra"))

r_ll = project(r, "EPSG:2169")

