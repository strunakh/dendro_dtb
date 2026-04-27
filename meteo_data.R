library(tidyverse)
library(lubridate)
library(plantecophys)

# ------------------------------------------------------------
# METEOROLOGICAL DATA CORRECTION
# ------------------------------------------------------------


input_dir_corr  <- "data/meteo_corr_input"
output_dir_corr <- "data/meteo_corr_output"


correct_station <- function(target_id, reference_id) {
  
  target <- read.csv(
    file.path(in_dir, paste0(target_id, ".txt")),
    check.names = FALSE
  )
  
  reference <- read.csv(
    file.path(in_dir, paste0(reference_id, ".txt")),
    check.names = FALSE
  )
  
  colnames(target)    <- c("row_id", "ts", "temp", "humidity", "dew_point", "serial_number")
  colnames(reference) <- c("row_id", "ts", "temp", "humidity", "dew_point", "serial_number")
  
  target$ts    <- ymd_hms(target$ts)
  reference$ts <- ymd_hms(reference$ts)

  # Select variables used for model calibration
  
  target_small <- target |> select(ts, temp, humidity, dew_point)
  reference_small <- reference |> select(ts, temp, humidity, dew_point)
  
  # Train models on overlapping period
  common_data <- inner_join(
    target_small,
    reference_small,
    by = "ts",
    suffix = c("_target", "_reference")
  )
  
  model_temp <- lm(temp_target ~ temp_reference, data = common_data)
  model_humidity <- lm(humidity_target ~ humidity_reference, data = common_data)
  model_dew_point <- lm(dew_point_target ~ dew_point_reference, data = common_data)
  
  # optional model summaries check
  message("Model for: ", target_id)
  print(summary(model_temp))
  print(summary(model_humidity))
  print(summary(model_dew_point))

  # Select period after the last available target measurement  
  last_ts <- max(target$ts, na.rm = TRUE)
  
  missing_part <- reference_small |>
    filter(ts > last_ts) |>
    rename(
      temp_reference = temp,
      humidity_reference = humidity,
      dew_point_reference = dew_point
    )
  
  # predict missing values
  missing_part$temp <- predict(model_temp, newdata = missing_part)
  missing_part$humidity <- predict(model_humidity, newdata = missing_part)
  missing_part$dew_point <- predict(model_dew_point, newdata = missing_part)
  
  missing_part <- missing_part |>
    transmute(
      row_id = NA,
      ts = ts,
      temp = round(temp, 1),
      humidity = round(humidity, 1),
      dew_point = round(dew_point, 1),
      serial_number = NA
    )
  
  # Combine measured and predicted dat
  corrected_target <- bind_rows(target, missing_part) |>
    arrange(ts) |>
    mutate(
      temp = round(temp, 1),
      humidity = round(humidity, 1),
      dew_point = round(dew_point, 1)
    )
  
  corrected_target$ts <- format(corrected_target$ts, "%Y-%m-%d %H:%M:%S") # fixes issue with midnight
  
  write.table(
    corrected_target,
    file = file.path(out_dir, paste0(target_id, "_corrected.txt")),
    row.names = FALSE,
    sep = ",",
    dec = ".",
    quote = FALSE
  )
  
  message("Corrected: ", target_id, " using ", reference_id)
}

# Run corrections
correct_station("CZE_1_3", "CZE_1_4")
correct_station("CZE_2_1", "CZE_2_4")


# ------------------------------------------------------------
# VAPOR PRESSURE DEFICIT CALCULATION
# ------------------------------------------------------------

in_dir  <- "C:/Users/user/OneDrive/Počítač/bp/databáza/data/meteo_input"
out_dir <- "C:/Users/user/OneDrive/Počítač/bp/databáza/data/meteo_processed"

files <- list.files(in_dir, pattern = "\\.txt$", full.names = TRUE)

for (f in files) {
  
  df <- read.csv(f, check.names = FALSE)
  
  colnames(df) <- c("row_id", "ts", "temp", "humidity", "dew_point", "serial_number")
  
  df$ts <- ymd_hms(df$ts)
  df$temp <- as.numeric(df$temp)
  df$humidity <- as.numeric(df$humidity)
  
  # Calculate vapor pressure deficit
  df$vpd <- RHtoVPD(T = df$temp, RH = df$humidity)
  
  df$vpd <- round(df$vpd, 2)
  
  df_export <- df |>
    transmute(
      Time = format(ts, "%Y-%m-%d %H:%M:%S"),
      temp,
      humidity,
      dew_point,
      vpd
    )
  
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


