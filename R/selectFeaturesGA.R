selectFeaturesGA = function(learner, task, resampling, measures, bit.names, bits.to.features, control, opt.path, show.info) {
  fit = measureAggrName(measures[[1]])
  # generate mu feature sets (of correct size)
  states = list()
  mu = control$extra.args$mu
  lambda = control$extra.args$lambda
  yname = opt.path$y.names[1]
  minimize = opt.path$minimize[1]
  for (i in 1:mu) {
    while(TRUE) {
      states[[i]] = rbinom(length(bit.names), 1, 0.5)
      if(is.na(control$max.features) || sum(states[[i]] <= control$max.features))
        break
    }
  }
  evalOptimizationStates(learner, task, resampling, measures, NULL, 
    bits.to.features, control, opt.path, show.info, states, 0L, as.integer(NA), FALSE)  
  pop.inds = 1:mu
  for(i in 1:control$maxit) {
    # get all mu elements which are alive, ie the current pop and their bit vecs as matrix
    pop.df = as.data.frame(opt.path)[pop.inds, ]
    pop.featmat = as.matrix(pop.df[, bit.names]); mode(pop.featmat) = "integer"
    pop.y = pop.df[, yname]
    # create lambda offspring and eval
    kids.list = replicate(lambda, generateKid(pop.featmat, control), simplify=FALSE)
    kids.y = evalOptimizationStates(learner, task, resampling, measures, NULL, 
      bits.to.features, control, opt.path, show.info, states = kids.list, i, as.integer(NA), FALSE)
    kids.y = extractSubList(kids.y, yname)
    oplen = getOptPathLength(opt.path)
    kids.inds = seq(oplen - lambda + 1, oplen)
    if (control$extra.args$comma) {
      # if comma, kill current pop and keep only mu best of offspring
      setOptPathElEOL(opt.path, pop.inds, i-1)
      pool.inds = kids.inds
      pool.y = kids.y
    } else {
      # if plus, keep best of pop + offspring
      pool.inds = c(pop.inds, kids.inds)
      pool.y = c(pop.y, kids.y)
    }
    # get next pop of best mu from pool
    pop.inds = pool.inds[order(pool.y, decreasing=!minimize)[1:mu]]
    setOptPathElEOL(opt.path, setdiff(pool.inds, pop.inds), i)
  }
  i = getOptPathBestIndex(opt.path, measureAggrName(measures[[1]]), ties="random")
  e = getOptPathEl(opt.path, i)
  makeFeatSelResult(learner, control, names(e$x)[e$x == 1], e$y, opt.path)
}


# sample 2 random parents, CX, mutate --> 1 kid 
# (repeat in a loop if max.features not satisfied)
generateKid = function(featmat, control) {
  parents = sample(1:nrow(featmat), 2, replace=TRUE)
  while(TRUE) {
    kid = crossover(featmat[parents[1],], featmat[parents[2],], control$extra.args$crossover.rate)
    kid = mutateBits(kid, control$extra.args$mutation.rate)
    if(is.na(control$max.features) || sum(kid) <= control$max.features)
      break
  }
  return(kid)
}