library(dendRoAnalyst)
library(lubridate)

in_dir  <- "C:/Users/user/OneDrive/Počítač/bp/data/2025_05/dendro"
out_dir <- "C:/Users/user/OneDrive/Počítač/bp/data/2025_05/dendro_clean"
dir.create(out_dir, showWarnings = FALSE)


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

