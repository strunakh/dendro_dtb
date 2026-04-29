library(dendRoAnalyst)
library(lubridate)
library(treenetproc)


# ------------------------------------------------------------
# DENDROMETER DATA CORRECTION
# ------------------------------------------------------------


in_dir  <- "C:/Users/user/OneDrive/Počítač/bp/data/2025_05/dendro"
out_dir <- "C:/Users/user/OneDrive/Počítač/bp/data/2025_05/dendro_clean"

# Find all text files in the input folder
files <- list.files(in_dir, pattern = "\\.txt$", full.names = TRUE)

# Read raw dendrometer data.
# Decimal commas are used in the original files.
for (f in files) {
  tree <- read.table(f,
                     header = TRUE,
                     sep    = "",
                     dec    = ",")


  # Rename columns to a unified structure
  colnames(tree) <- c("DATE", "TIME", "Increment", "Temperature")

  # Create a single timestamp column from date and time
  tree$ts <- ymd_hms(paste(tree$DATE, tree$TIME))  # column ts

  # Keep only relevant columns and rename them for further processing
  tree <- tree[, c("ts", "Increment", "Temperature")] 
  colnames(tree) <- c("ts", "increment", "temp")      

  # Create a copy of the data for correction
  tree_clean <- tree 
  
  # Plot the original increment series for visual inspection
  plot(tree_clean$ts, tree_clean$increment,
       type = "l", xlab = "Time", ylab = "Increment")
  
 # Store original values to count how many values were changed
  before <- tree_clean$increment
  
  # Detect and correct non-physiological jumps in the increment series
  tree_clean[, c("ts","increment")] <-
    jump.locator(tree_clean[, c("ts","increment")], v = 5)
  
  changed <- sum(before != tree_clean$increment, na.rm = TRUE)
  
  if (changed > 0) {
    message("Tree ", basename(f),
            " – values fixed: ", changed)
  }

  # Add corrected series to the original plot
  lines(tree_clean$ts, tree_clean$increment, col = "red")

  # Plot the corrected series separately
  plot(tree_clean$ts, tree_clean$increment,
       type = "l", col = "red", xlab = "Time", ylab = "Increment") 
  
  # Create output file name
  out_name <- paste0(tools::file_path_sans_ext(basename(f)), "_clean.txt")

  # Convert timestamp to character format.
  # This prevents problems with missing midnight values during later processing.
  tree_clean$ts <- format(tree_clean$ts, "%Y-%m-%d %H:%M:%S")

  # Export cleaned dendrometer data
  write.table(tree_clean,
              file      = file.path(out_dir, out_name),
              row.names = FALSE,
              sep       = "\t",   
              dec       = ".", 
              quote     = FALSE)   
}

# ------------------------------------------------------------
# CALCULATION OF DERIVED DENDROMETER VARIABLES
# ------------------------------------------------------------

files <- list.files(out_dir, pattern = "_clean\\.txt$", full.names = TRUE)

for (f in files) {

  # Read cleaned dendrometer data
  tree <- read.delim(f, sep = "\t", dec = ".", header = TRUE)
  tree$ts <- ymd_hms(tree$ts)
  
  # Process dendrometer data using the treenetproc package.
  # L1 performs temporal alignment to hourly resolution.
  # L2 derives biologically interpretable variables such as maximum stem size and TWD.
  # High tolerance values are used because major jumps were already corrected beforehand.
  tree_proc <- proc_dendro_L2(
    proc_L1(tree, input = "wide", reso = 60),
    tol_out = 10000,
    tol_jump = 10000
  )

  # Calculate hourly growth as the difference between consecutive maximum stem sizes
  tree_proc$gro <- 0
  tree_proc$gro[2:nrow(tree_proc)] <-
    tree_proc$max[2:nrow(tree_proc)] -
    tree_proc$max[1:(nrow(tree_proc) - 1)]

  # Calculate cumulative growth.
  tree_proc$gro_yr <- cumsum(pmax(tree_proc$gro, 0))
  
  tree_proc$gro <- round(tree_proc$gro, 6)
  tree_proc$gro_yr <- round(tree_proc$gro_yr, 6)

  # Round tree water deficit if it was calculated by treenetproc
  if ("twd" %in% names(tree_proc)) {
    tree_proc$twd <- round(tree_proc$twd, 6)
  }
  
  # Remove derived variables from the original table if they already exist.
  drop_cols <- intersect(c("gro", "gro_yr", "twd"), names(tree))
  if (length(drop_cols) > 0) tree[drop_cols] <- NULL

  # Select derived variables for export
  derived <- tree_proc[, c("ts", "gro", "gro_yr")]
  if ("twd" %in% names(tree_proc)) derived$twd <- tree_proc$twd

  # Merge original cleaned data with derived variables by timestamp
  tree <- merge(tree, derived, by = "ts", all.x = TRUE, sort = FALSE)
  
  tree$ts <- format(tree$ts, "%Y-%m-%d %H:%M:%S")

   # Overwrite the cleaned file with the extended version containing derived variables
  write.table(tree,
              file      = f,
              row.names = FALSE,
              sep       = "\t",
              dec       = ".",
              quote     = FALSE)
  
  message("Processed: ", basename(f))
}



