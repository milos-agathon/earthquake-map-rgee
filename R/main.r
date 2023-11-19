# STEP 1
install.packages("rgee")
library(rgee)

# STEP 2
install.packages("reticulate")
library(reticulate)

# STEP 3
reticulate::py_available()
reticulate::py_discover_config()

# STEP 4
rgee::ee_install_set_pyenv(
    py_path = "C:/Users/milos/AppData/Local/r-miniconda/envs/r-reticulate/python.exe", # PLEASE SET YOUR OWN PATH
    py_env = "rgee"
)

# STEP 5
rgee::ee_check()
rgee::ee_install_upgrade()

# initialize Earth Engine
rgee::ee_Initialize(
    user = "***********@gmail" # PLEASE SET YOUR OWN CREDENTIALS
)

libs <- c("sf", "giscoR", "elevatr", "rayshader", "terra")
invisible(
    lapply(
        libs, library,
        character.only = TRUE
    )
)

crs_lambert <- "+proj=laea +lat_0=52 +lon_0=10 +x_0=4321000 +y_0=3210000 +datum=WGS84 +units=m +no_frfs"

iceland_sf <- giscoR::gisco_get_countries(
    country = "IS",
    resolution = "3"
)

iceland_bbox <- sf::st_bbox(
    iceland_sf
)

iceland_bounds <- ee$Geometry$Rectangle(
    c(
        west = iceland_bbox[["xmin"]],
        south = iceland_bbox[["ymin"]],
        east = iceland_bbox[["xmax"]],
        north = iceland_bbox[["ymax"]]
    ),
    geodetic = TRUE,
    proj = "EPSG:4326"
)

# Get earthquake data
earthquake_data <- ee$FeatureCollection(
"projects/sat-io/open-datasets/USGS/usgs_earthquakes_1923-2023"
)$
filterBounds(
    iceland_bounds
)

rgee::ee_print(earthquake_data)

earthquake_iceland <- rgee::ee_as_sf(
    earthquake_data,
    maxFeatures = 5000
) |>
sf::st_transform(
    crs_lambert
)

# Get elevation data

elev <- elevatr::get_elev_raster(
    locations = iceland_sf,
    z = 8, clip = "locations"
)

elev_lambert <- elev |>
    terra::rast() |>
    terra::project(
        crs_lambert
    )

elmat <- rayshader::raster_to_matrix(elev_lambert)

# Render scene

h <- nrow(elev_lambert)
w <- ncol(elev_lambert)

elmat |>
    rayshader::height_shade(
        texture = colorRampPalette(
            c(
                "grey80",
                "grey40"
            )
        )(512)
    ) |>
    rayshader::add_overlay(
        rayshader::generate_point_overlay(
            earthquake_iceland,
            color = "red",
            size = 12,
            extent = elev_lambert,
            heightmap = elmat
        )
    ) |>
    rayshader::plot_3d(
        elmat,
        zscale = 12,
        solid = F,
        shadow = T,
        shadow_darkness = 1,
        background = "white",
        windowsize = c(
            w / 8, h / 8
        ),
        zoom = .515,
        phi = 87,
        theta = 0
    )

# Render object

rayshader::render_highquality(
    filename = "iceland-earthquakes.png",
    preview = T,
    light = F,
    environment_light = "air_museum_playground_4k.hdr",
    intensity_env = 1,
    rotate_env = 90,
    interactive = F,
    parallel = T,
    width = w,
    height = h 
)
