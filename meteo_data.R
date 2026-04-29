library(tidyverse)
library(lubridate)
library(plantecophys)

# ------------------------------------------------------------
# METEOROLOGICAL DATA CORRECTION
# ------------------------------------------------------------


input_dir_corr  <- "data/meteo_corr_input"
output_dir_corr <- "data/meteo_corr_output"


# Function for correcting missing measurements at one station
# using a reference open-space station from the same elevation belt.
correct_station <- function(target_id, reference_id) {
  
  # Read target station data and reference station data
  target <- read.csv(
    file.path(input_dir_corr, paste0(target_id, ".txt")),
    check.names = FALSE
  )
  
  reference <- read.csv(
    file.path(input_dir_corr, paste0(reference_id, ".txt")),
    check.names = FALSE
  )
  
  # Rename columns to a unified structure
  colnames(target)    <- c("row_id", "ts", "temp", "humidity", "dew_point", "serial_number")
  colnames(reference) <- c("row_id", "ts", "temp", "humidity", "dew_point", "serial_number")
  
  # Convert timestamp column to date-time format
  target$ts    <- ymd_hms(target$ts)
  reference$ts <- ymd_hms(reference$ts)

  # Select only variables used for regression model calibration
  target_small <- target |> 
    select(ts, temp, humidity, dew_point)
  
  reference_small <- reference |> 
    select(ts, temp, humidity, dew_point)
  
  # Join target and reference station data by timestamp.
  # Only the overlapping period is used for model calibration.
  common_data <- inner_join(
    target_small,
    reference_small,
    by = "ts",
    suffix = c("_target", "_reference")
  )
  
  # Build separate linear regression models for each meteorological variable
  model_temp <- lm(temp_target ~ temp_reference, data = common_data)
  model_humidity <- lm(humidity_target ~ humidity_reference, data = common_data)
  model_dew_point <- lm(dew_point_target ~ dew_point_reference, data = common_data)
  
  # Print model summaries for checking model quality
  message("Model for: ", target_id)
  print(summary(model_temp))
  print(summary(model_humidity))
  print(summary(model_dew_point))

  # Find the last available timestamp in the target station data
  last_ts <- max(target$ts, na.rm = TRUE)
  
  # Select the period after the last available target measurement from the reference station data
  missing_part <- reference_small |>
    filter(ts > last_ts) |>
    rename(
      temp_reference = temp,
      humidity_reference = humidity,
      dew_point_reference = dew_point
    )
  
  # Predict missing values using the calibrated regression models
  missing_part$temp <- predict(model_temp, newdata = missing_part)
  missing_part$humidity <- predict(model_humidity, newdata = missing_part)
  missing_part$dew_point <- predict(model_dew_point, newdata = missing_part)
  
  # Prepare predicted data in the same structure as the original file
  missing_part <- missing_part |>
    transmute(
      row_id = NA,
      ts = ts,
      temp = round(temp, 1),
      humidity = round(humidity, 1),
      dew_point = round(dew_point, 1),
      serial_number = NA
    )
  
  # Combine measured and predicted data
  corrected_target <- bind_rows(target, missing_part) |>
    arrange(ts) |>
    mutate(
      temp = round(temp, 1),
      humidity = round(humidity, 1),
      dew_point = round(dew_point, 1)
    )
  
  # Convert timestamp back to character format.
  # This prevents problems with missing midnight values during later processing.
  corrected_target$ts <- format(corrected_target$ts, "%Y-%m-%d %H:%M:%S")
  
  # Export corrected station data
  write.table(
    corrected_target,
    file = file.path(output_dir_corr, paste0(target_id, "_corrected.txt")),
    row.names = FALSE,
    sep = ",",
    dec = ".",
    quote = FALSE
  )
  
  message("Corrected: ", target_id, " using ", reference_id)
}


# Run corrections for selected stations
correct_station("CZE_1_3", "CZE_1_4")
correct_station("CZE_2_1", "CZE_2_4")


# ------------------------------------------------------------
# VAPOR PRESSURE DEFICIT CALCULATION
# ------------------------------------------------------------

# Input and output folders for processed meteorological data
in_dir  <- "C:/Users/user/OneDrive/Počítač/bp/databáza/data/meteo_input"
out_dir <- "C:/Users/user/OneDrive/Počítač/bp/databáza/data/meteo_processed"

# Find all meteorological text files in the input folder
files <- list.files(in_dir, pattern = "\\.txt$", full.names = TRUE)

for (f in files) {
  
  # Read meteorological data
  df <- read.csv(f, check.names = FALSE)
  
  # Rename columns to a unified structure
  colnames(df) <- c("row_id", "ts", "temp", "humidity", "dew_point", "serial_number")
  
  # Convert timestamp and selected variables to appropriate data types
  df$ts <- ymd_hms(df$ts)
  df$temp <- as.numeric(df$temp)
  df$humidity <- as.numeric(df$humidity)
  
  # Calculate vapor pressure deficit from temperature and relative humidity
  df$vpd <- RHtoVPD(T = df$temp, RH = df$humidity)
  df$vpd <- round(df$vpd, 2)
  
  # Prepare final output table
  df_export <- df |>
    transmute(
      Time = format(ts, "%Y-%m-%d %H:%M:%S"),
      temp,
      humidity,
      dew_point,
      vpd
    )
  
  # Export processed meteorological data
  write.table(
    df_export,
    file = file.path(out_dir, paste0(tools::file_path_sans_ext(basename(f)), ".txt")),
    row.names = FALSE,
    sep = ",",
    dec = ".",
    quote = FALSE
  )
  
  message("Processed: ", basename(f))
}
