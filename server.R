library(shiny)
library(poppr)
library(ape)
library(igraph)
df <- read.table("reduced_database.txt.csv", header=TRUE, sep="\t")
df.m <- as.matrix(df)
#newrow <- c()
msn.plot <- NULL
labs <- NULL
p <- NULL
a <- NULL
gen <- NULL
random.sample <- 1
ssr <- c(3,3,2,3,3,2,2,3,3,3,3,3)
# Function that will add extra zeroes onto genotypes that are deficient in the right number of alleles.
addzeroes <- function(x, ploidy = 3){
  extras <- ploidy - vapply(strsplit(x, "/"), length, 69)
  vapply(1:length(extras), function(y){
    if(extras[y] > 0){
      return(paste(c(x[y], rep(0, extras[y])), collapse = "/"))
    }
    else{
      return(x[y])
    }
  }, "out")
}

shinyServer(function(input, output) {
 
  treeInput <- reactive({
    switch(input$tree,
           "upgma" = "upgma",
           "nj" = "nj"
           )
  })

output$distPlotTree <- renderPlot({
    #newrow <<- c("query", "???", input$mst1, input$mst2, input$mst3, input$mst4, input$mst5, input$mst6, input$mst7, input$mst8, input$mst9)
    if (gsub("\\s", "", input$table) == ""){
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n') + rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + text(x = 0.5, y = 0.9, "No SSR data has been input.", cex = 1.6, col = "white")
    }
    else{
      p <- c(input$table)
      b <- unlist(strsplit(p, c("\n")))
      b <- sub(" ", "\t", b)
      b <- strsplit(b, c("\t"))
      t <- t(as.data.frame(b))
      rownames(t) <- NULL
      colnames(t) <- colnames(df.m)
      df.m <- rbind(df.m, t, deparse.level = 0)
      df.m <- as.data.frame(df.m)
      gen <<- df2genind(df.m[, -c(1, 2)], ploid = 2, sep = "/", pop = df.m[, 2], ind.names = df.m[, 1])
      # popchar <- nchar(levels(pop(gen)))
      # maxchar <- max(popchar)
      # levels(pop(gen)) <- paste(levels(pop(gen)), vapply(popchar, function(x) paste(rep(" ", maxchar - x), collapse = ""), ""))
      if (input$boot > 1000){
        plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n') + rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + text(x = 0.5, y = 0.9, "The number of bootstrap repetitions should be less or equal to 2000", cex = 1.6, col = "white")
      }
      else if (input$boot < 10){
        plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n') + rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + text(x = 0.5, y = 0.9, "The number of bootstrap repetitions should be greater than 10", cex = 1.6, col = "white")
      }
      else{
       #Adding colors to the tip values according to the clonal lineage
       gen$other$tipcolor <<- pop(gen)
       levels(gen$other$tipcolor) <<- c("blue", "darkcyan", "darkolivegreen", "darkgoldenrod", "red", rainbow(length(levels(gen$other$tipcolor)) - 4))
       gen$other$tipcolor <<- as.character(gen$other$tipcolor)
         #Running the tree, setting a cutoff of 50 and saving it into a variable to be plotted (a)
       if (input$tree=="nj"){
        a <<- bruvo.boot(gen, replen = ssr, sample=input$boot, tree=input$tree, cutoff=50)
        a <<- phangorn::midpoint(ladderize(a))
       }
       else {
         a <<- bruvo.boot(gen, replen = ssr, sample = input$boot, tree = input$tree, cutoff = 50)
       }
       #Drawing the tree
       plot.phylo(a)
       #Adding the tip lables from each population, and with the already defined colors
       tiplabels(pop(gen), adj = c(-4, 0.5), frame = "n", col = gen$other$tipcolor, cex = 0.8, font = 2)
       
       #Adding the nodel labels: Bootstrap values.
       nodelabels(a$node.label, adj = c(1.2, -0.5), frame = "n", cex = 0.9, font = 3)
       
       if (input$tree == "upgma"){
         axisPhylo(3)
       }
       else if (input$tree == "nj"){
         add.scale.bar(x = 0.89, y = 1.18, length = 0.05, lwd = 2)
       }
     }
   }
  })
  
#Minimum Spanning Network
  output$MinSpanTree <- renderPlot({
    if (gsub("\\s", "", input$table) == ""){
      plot(c(0, 1), c(0, 1), ann = F, bty = 'n', type = 'n', xaxt = 'n', yaxt = 'n') + rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + text(x = 0.5, y = 0.9, "No SSR data has been input.", cex = 1.6, col = "white")
    }
    else{
      p <- c(input$table)
      b <- unlist(strsplit(p, c("\n")))
      b <- sub(" ", "\t", b)
      b <- strsplit(b, c("\t"))
      t <- t(as.data.frame(b))
      rownames(t) <- NULL
      colnames(t) <- colnames(df.m)
      
      df.m <- rbind(df.m, t, deparse.level = 0)
      df.m <- as.data.frame(df.m)
      gen <<- df2genind(df.m[, -c(1, 2)], ploid = 2, sep = "/", pop = df.m[, 2], ind.names = df.m[, 1])
      msn.plot <<- bruvo.msn(gen, replen = ssr)
      V(msn.plot$graph)$size <<- 10

      # Highlighting only the names of the submitted genotypes and the isolates they match with.
      number_of_queries <- nrow(t)
      gen.mlg <- mlg.vector(gen)
      gen.input <- unique(gen.mlg[(1+length(gen.mlg)-number_of_queries):length(gen.mlg)])
      labs <- unlist(strsplit(V(msn.plot$graph)$label, "\\."))
      labs <- as.numeric(labs[!labs %in% "MLG"])
      chosenlabs <- labs[which(labs %in% gen.input)]
      gen.input <- gen.input[vapply(chosenlabs, function(x) which(gen.input == x), 1)]
      combined_names <- vapply(gen.input, function(x) paste(rev(gen@ind.names[gen.mlg == x]), collapse = "\n"), " ")
      labs[which(!labs %in% gen.input)] <- NA
      labs[!is.na(labs)] <- combined_names
      labs <<- labs

      #x <<- sample(10000, 1)
      x <<- 200
      set.seed(x)
      plot.igraph(msn.plot$graph, vertex.label = labs, vertex.label.font = 2, vertex.label.dist = 0.5, vertex.label.color = "firebrick")
      legend("topleft" , bty = "n", cex = 1.2, legend = msn.plot$populations, title = "Populations", fill = msn.plot$color, border = NULL)
    }   
    
  })
  
  
  output$downloadData <- downloadHandler(
    filename = function() { paste(input$tree, '.tre', sep = '') },
    content = function(file) {
      write.tree(a, file)
    })
  
  output$downloadPdf <- downloadHandler(
    filename = function() { paste(input$tree, '.pdf', sep = '') },
    content = function(file) {
      pdf(file)
      plot.phylo(a, cex = 0.5)
      tiplabels(pop(gen), adj = c(-4, 0.5), frame = "n", col = gen$other$tipcolor, cex = 0.4, font = 2)
      nodelabels(a$node.label, adj = c(1.2, -0.5), frame = "n", cex = 0.4, font = 3)
      if (input$tree == "upgma"){
        axisPhylo(3)
        }
      dev.off()
  })

  output$downloadPdfMst <- downloadHandler(
    filename = function() { paste("min_span_net", '.pdf', sep = '')} ,
    content = function(file) {
    pdf(file)
    set.seed(x)
    plot.igraph(msn.plot$graph, , vertex.label = labs, vertex.label.font = 2, vertex.label.dist = 0.5, vertex.label.color = "firebrick")
    legend("topleft" , bty = "n", cex = 1.2, legend = msn.plot$populations, title = "Populations", fill = msn.plot$color, border = NULL)
    dev.off()
  }
  )
  
})
