% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/simulations.R
\name{rand_start}
\alias{rand_start}
\title{rand_start}
\usage{
rand_start(sims, n = 2, mindist = NULL, nsim = 100, maxit = 10000)
}
\arguments{
\item{sims}{either a matrix of outputs from sim_gen, a directory, or a list of files.}

\item{n}{generate n start points for simulation.}

\item{mindist}{generate start points for simulation at least this far apart (distance measured by d_par). Overrides n if set.}

\item{nsim}{use this many simulations to determine cluster points. Reading a large number of files (as is the case when parameter 'sims' is a list) can be slow.}

\item{maxit}{if the E-M algorithm uses the maximum allowed number of iterations, it may not have converged. Set this parameter to restrict to only simulations taking fewer than this number of iterations.}
}
\description{
For a given directory or matrix of outputs from function sim_gen, computes a corresponding set of start points for the E-M algorithm on subsequent simulations.
}
\examples{
data(sim_mat)
sim_start(sim_mat)
}
\author{
James Liley
}

