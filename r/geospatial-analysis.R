# Libraries ----
library(tidygeocoder) 
library(sf)           
library(mapview)      
library(tigris)       
library(tidyverse)    

# Data ----

travel <- read_csv(here::here("data","travel.csv"))
travel

sales_geo <- read_csv("data/customer_sales_geocoded.csv")
sales_geo

# Testing out packages and functions ----
## Geocoding -----

location = c("Sacramento, CA")
l = as.data.frame(location)
rm(location)

geo(l[1,1], method = "arcgis")

location_latlon <- l %>%
    geocode(
        address = location,
        method  = "arcgis"
    )

location_latlon %>%
    reverse_geocode(
        lat     = "lat",
        long    = "long",
        address = "estimated_address",
        method  = "arcgis"
    )


## Simple Features ----

location_latlon_sf <- location_latlon %>%
    st_as_sf(
        coords = c("long", "lat"),
        crs    = 4326
    )

location_latlon_sf %>% mapview()


# EDA ----

destinations <- travel %>%
    group_by(travelcountry, travellat, travellon) %>%
    summarize(n = n()) %>%
    ungroup() %>%
    arrange(desc(n))

destinations

destinations_sf <- destinations %>%
    st_as_sf(
        coords = c("travellon", "travellat"),
        crs    = 4326
    )

## View Destination----
destinations_sf %>%
    mapview(
        cex           = "n",
        col.regions   = "#0197F6",
        alpha.regions = 0.5
    )
## Travel ----
travel_connections <- travel %>%
    group_by(homelat, homelon, travellat, travellon) %>%
    summarize(n = n()) %>%
    ungroup() %>%
    arrange(desc(n)) %>%
    rowid_to_column()


travel_connections_pl <- travel_connections %>%
    pivot_longer(cols = homelat:travellon) %>%
    mutate(type = ifelse(str_detect(name, "^home"), "home", "travel")) %>%
    mutate(latlon = ifelse(str_detect(name, "lat$"), "lat", "lon")) %>%
    select(-name, -n) %>%
    pivot_wider(
        names_from  = latlon,
        values_from = value
    )


travel_connection_sf <- travel_connections_pl %>%
    st_as_sf(
        coords = c("lon", "lat"),
        crs    = 4326
    )

travel_connection_multipoints_sf <- travel_connection_sf %>%
    group_by(rowid) %>%
    summarise(do.union = FALSE)

travel_connection_multipoints_sf %>%
  mapview(
    col.regions   = "#0197F6",
    alpha.regions = 0.5
    )
    
travel_connection_lines_sf <- travel_connection_multipoints_sf %>%
    st_cast("LINESTRING")

travel_connection_lines_sf %>% 
  mapview(
    lwd   = 0.05,
    color = "#0197F6"
    )

travel_connection_lines_sf %>%
    left_join(
        travel_connections %>% 
          select(rowid, n)
    ) %>%
    mapview(
        lwd   = 0.05,
        color = "#B2B5B6",
        legend = FALSE
    ) +
    mapview(
        destinations_sf,
        col.regions   = "#0197F6",
        col           = "#0197F6",
        cex           = "n",
        alpha.regions = 0.1,
        alpha         = 0.1,
        legend = FALSE
    )

## Sales/Customer Analysis ----

sales_geo_sf <- sales_geo %>%
    st_as_sf(
        coords = c("lat", "lon"),
        crs    = 4326
    )

sales_geo_sf %>%
    mapview(
      cex = "purchases",
      col.regions = "#0197F6")

ca_counties_sf <- tigris::counties(state = "CA") %>%
    st_set_crs(4326)

ca_counties_sf %>% 
  mapview(col.regions = "#0197F6",
          col = "black")

sales_by_county_sf <- sales_geo_sf %>%
  st_join(ca_counties_sf %>%
            select(GEOID)) %>%
    as_tibble() %>%
    group_by(GEOID) %>%
    summarize(
        median_purchases = median(purchases),
        avg_purchases = mean(purchases),
        sum_purchases    = sum(purchases)
    ) %>%
    ungroup() %>%
    right_join(ca_counties_sf, by = "GEOID") %>%
    select(GEOID:sum_purchases, NAME, geometry) %>%
    st_as_sf(crs = 4326)

sales_by_county_sf %>%
    mapview(
        zcol       = "avg_purchases",
        color      = "grey",
        map.types  = "CartoDB",
        layer.name = "Average Purchases"
    )

sales_by_county_sf %>%
    mapview(
        zcol       = "sum_purchases",
        color      = "grey",
        map.types  = "CartoDB",
        layer.name = "Sum Purchases"
    )

### Kmeans ----
set.seed(1)
kmeans_obj <- sales_geo_sf %>%
    st_coordinates() %>%
    as_tibble() %>%
    kmeans(centers = 5, nstart = 20)

kmeans_obj$cluster

sales_geo_sf %>%
    mutate(cluster = kmeans_obj$cluster %>% factor()) %>%
    mapview(
        zcol       = "cluster",
        cex        = "purchases",
        color      = "grey",
        map.types  = "CartoDB",
        layer.name = "Geospatial Segments"
    )