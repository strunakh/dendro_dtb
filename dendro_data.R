library(dendRoAnalyst)
library(lubridate)
library(treenetproc)


### CORRECTION

in_dir  <- "C:/Users/user/OneDrive/Počítač/bp/data/2025_05/dendro"
out_dir <- "C:/Users/user/OneDrive/Počítač/bp/data/2025_05/dendro_clean"


files <- list.files(in_dir, pattern = "\\.txt$", full.names = TRUE)

for (f in files) {
  tree <- read.table(f,
                     header = TRUE,
                     sep    = "",
                     dec    = ",")

  
  colnames(tree) <- c("DATE", "TIME", "Increment", "Temperature")

  tree$ts <- ymd_hms(paste(tree$DATE, tree$TIME))  # column ts
  
  tree <- tree[, c("ts", "Increment", "Temperature")] 
  colnames(tree) <- c("ts", "increment", "temp")      
  
  tree_clean <- tree 
  

  plot(tree_clean$ts, tree_clean$increment,
       type = "l", xlab = "Time", ylab = "Increment")
  

  before <- tree_clean$increment
  

  tree_clean[, c("ts","increment")] <-
    jump.locator(tree_clean[, c("ts","increment")], v = 5)
  
  changed <- sum(before != tree_clean$increment, na.rm = TRUE)
  
  if (changed > 0) {
    message("Tree ", basename(f),
            " – values fixed: ", changed)
  }
  
  lines(tree_clean$ts, tree_clean$increment, col = "red")
  
  plot(tree_clean$ts, tree_clean$increment,
       type = "l", col = "red", xlab = "Time", ylab = "Increment") 
  

  out_name <- paste0(tools::file_path_sans_ext(basename(f)), "_clean.txt")
  
  tree_clean$ts <- format(tree_clean$ts, "%Y-%m-%d %H:%M:%S")
  
  write.table(tree_clean,
              file      = file.path(out_dir, out_name),
              row.names = FALSE,
              sep       = "\t",   
              dec       = ".", 
              quote     = FALSE)   
}

### FUNCTION TO CALCULATE

files <- list.files(out_dir, pattern = "_clean\\.txt$", full.names = TRUE)

for (f in files) {
  tree <- read.delim(f, sep = "\t", dec = ".", header = TRUE)
  tree$ts <- ymd_hms(tree$ts)
  
  # L1 + L2
  tree_proc <- proc_dendro_L2(
    proc_L1(tree, input = "wide", reso = 60),
    tol_out = 10000,
    tol_jump = 10000
  )
  
  tree_proc$gro <- 0
  tree_proc$gro[2:nrow(tree_proc)] <-
    tree_proc$max[2:nrow(tree_proc)] -
    tree_proc$max[1:(nrow(tree_proc) - 1)]
  
  tree_proc$gro_yr <- cumsum(pmax(tree_proc$gro, 0))
  
  tree_proc$gro <- round(tree_proc$gro, 6)
  tree_proc$gro_yr <- round(tree_proc$gro_yr, 6)
  
  if ("twd" %in% names(tree_proc)) {
    tree_proc$twd <- round(tree_proc$twd, 6)
  }
  

  drop_cols <- intersect(c("gro", "gro_yr", "twd"), names(tree))
  if (length(drop_cols) > 0) tree[drop_cols] <- NULL
  
  derived <- tree_proc[, c("ts", "gro", "gro_yr")]
  if ("twd" %in% names(tree_proc)) derived$twd <- tree_proc$twd
  
  tree <- merge(tree, derived, by = "ts", all.x = TRUE, sort = FALSE)
  
  tree$ts <- format(tree$ts, "%Y-%m-%d %H:%M:%S")
  
  write.table(tree,
              file      = f,
              row.names = FALSE,
              sep       = "\t",
              dec       = ".",
              quote     = FALSE)
  
  message("Processed: ", basename(f))
}



