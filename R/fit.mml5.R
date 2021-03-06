##' Fit a specific Gaussian mixture distribution. See main text for details.
##' @title fit.3g
##' @param Z an n x 2 array; Z[i,1], Z[i,2] are the Z_d and Z_a scores respectively for the ith SNP
##' @param pars vector containing initial values of pi0,pi1,tau,sigma1,sigma2,rho.
##' @param weights SNP weights to adjust for LD; output from LDAK procedure
##' @param C a term C*log(pi0*pi1*pi2) is added to the likelihood so the model is specified.
##' @param fit_null set to TRUE to fit null model rho=0, tau=0
##' @param maxit maximum number of iterations before algorithm halts
##' @param tol how small a change in pseudo-likelihood halts the algorithm
##' @param sg1 set to TRUE to force sigma1>=1, sigma2>=1, tau>=1.
##' @param accel attempts to accelerate the fitting process by taking larger steps.
##' @param verbose prints current parameters with frequency defined by 'n_save'
##' @param save history to a file with frequency defined by 'n_save'
##' @param b_int save or print pars every b_int iterations
##' @param incl_z set to 'true' to include Z and weights in output. If 'false' these are set to null.
##' @return a list of six objects (class 3Gfit): pars is vector of fitted parameters, history is a matrix of fitted parameters and pseudo-likelihood at each stage in the E-M algorithm, logl is the joint pseudo-likelihood of Z_a and Z_d, logl_a is the pseudo-likelihood of Z_a alone (used for adjusting PLR),  z_ad is n x 2 matrix of Z_d and Z_a scores, weights is the weights used to generate the model, and hypothesis is 0 or 1 depending on the value of fit_null.
##' @export
##' @author Chris Wallace and James Liley
##' @examples
##' nn=100000
##' Z=abs(rbind(rmnorm(0.8*nn,varcov=diag(2)), rmnorm(0.15*nn,varcov=rbind(c(1,0),c(0,2^2))), rmnorm(0.05*nn,varcov=rbind(c(3^2,2),c(2,4^2))))); weights=runif(nn)
##' yy=fit.3g(Z,pars=c(0.7,0.2,2.5,1.5,3,1),weights=weights,incl_z=TRUE)
##' yy$pars
##' plot(yy,rlim=2)
fit.3g <- function(Z, pars=c(0.8,0.1,2,2,3,0.5), weights=rep(1,dim(Z)[1]), C=1, fit_null=FALSE, maxit=1e4, tol=1e-4, sg1=FALSE, accel=TRUE, verbose=TRUE, file=NULL, n_save=20, incl_z=TRUE) {

require(mnormt)
  # various error handlers
  if ((length(dim(Z))!=2) | (dim(Z)[1]!=length(weights))) stop("Z must be an n x 2 matrix, and 'weights' must be of length n")
  if (dim(Z)[2]!=2) stop("Z must be an n x 2 matrix")
  if (length(pars)!=6) stop("Parameter 'pars' must be a six-element vector containing values of (in order) pi0, pi1, tau, sigma1, sigma2, and rho")
  if (pars[1]>=1 | pars[2]>=1 | pars[1]<=0 | pars[2]<=0 | pars[1]+pars[2]>=1) stop("Values of pi0, pi1, and pi2 (pars[1],pars[2],1-pars[1]-pars[2]) must all be between 0 and 1")
  if (min(pars[3:5])<=0 | pars[6]<0) stop("The value of rho (pars[6]) must be nonnegative and values of tau, sigma1, and sigma2 (pars[3:5]) must be positive")
  if (pars[6]>pars[3]*pars[5]) stop("The covariance matrix (sigma1^2 rho \\ rho sigma2^2) must be positive definite (rho < sigma1*sigma2)")
  if (!is.null(file)) if (!file.exists(dirname(file))) stop(paste("Directory",dirname(file),"does not exist"))

  Z=abs(Z); ww=which(is.finite(Z[,1]+Z[,2])); Z=Z[ww,]; weights=weights[ww]
  pars=as.numeric(pars)
  
  ## probabilities of group0, group1, group2 membership
  px <- matrix(c(pars[1],pars[2],1-pars[1]-pars[2]),dim(Z)[1],3,byrow=TRUE)
  

  ## parameter vector
  if (fit_null) {
    pars[5]=1
    pars[6]=0
  }
  
  
  pars.fail <- function(pars) if (min(pars) < 0) TRUE else FALSE
  
  ## likelihood for each group; faster having separate functions
  lhood1 =function(scale) 4*scale*exp(-rowSums(Z^2)/2)/(2*3.14159265)
  
  lhood2 =function(scale,sigma) 4*scale*exp(-(Z[,1]^2 + (Z[,2]/sigma)^2)/2)/(2*3.14159265*sigma)
  
  lhood3 <- function(scale,sigma,rho) {
    vc=rbind(c(sigma[1]^2,rho),c(rho,sigma[2]^2)); sv=solve(vc)
    vc2=rbind(c(sigma[1]^2,-rho),c(-rho,sigma[2]^2)); sv2=solve(vc2)
    2*scale*( exp(-rowSums((Z %*% sv) * Z)/2)
              + exp(-rowSums((Z %*% sv2) * Z)/2) )/(2*3.14159265*sqrt(det(vc)))
  }
  
  
  
  
  ## likelihood function to be maximized
  lhood <- function(pars, sumlog=TRUE) {
    if (pars.fail(pars)) return(NA)
    e = lhood1(pars[1]) + lhood2(pars[2],pars[4]) + lhood3(1-pars[1]-pars[2],c(pars[3],pars[5]),pars[6])
    
    e[which(e==0)]=1e-64; e[which(!is.finite(e))]=1e64
    
    if(sumlog) {
      out=sum(weights*log(e)) + (C*log(pars[1]*pars[2]*(1-pars[1]-pars[2]))); names(out)="plhood"
      out
    } else e
  }
  
  
  
  # Derivative of log-likelihood with respect to rho. Computes with respect to the value 'rho' rather than pars[6].
  
  dlhood <- function(pars, rho) {
    s=pars[3]; t=pars[5]; s0=pars[4]
    pars_i=pars; pars_i[6]=rho
    
    dt= (s*t)^2 - rho^2
    
    cd=((Z[,2]*s)^2) + ((Z[,1]*t)^2)
    pd=Z[,1]*Z[,2]
    
    eab=exp(2*pd*rho/dt)
    eab2=exp(-(cd + (2*pd*rho))/(2*dt))
    
    num=exp((2*pd*rho-cd)/(2*dt))*((rho^3)- pd*(rho^2) + (rho*cd) - ((rho+pd)*((s*t)^2))) +
      eab2*(((rho^3) + pd*(rho^2) + (rho*cd) + ((pd-rho)*((s*t)^2))))
    denom=lhood(pars_i,sumlog=FALSE)
    
    sum(-((1-pars[1]-pars[2])/(3.1415*(dt^(5/2))))*weights*num/denom)
  }
  
  # Pseudo-likelihood of Z_a alone
  lhood_a=function(pars) {
    
    p=c(pars[1:2],1-pars[1]-pars[2])
    sds=c(1,pars[4:5])
    adj=C*log(prod(p))
    
    out=sum(weights* (
      -0.5 - (log(sqrt(2*3.1415))) + 
      log( (p[1]*dnorm(Z[,2],sd=sds[1])) + (p[2]*dnorm(Z[,2],sd=sds[2])) + (p[3]*dnorm(Z[,2],sd=sds[3])))
      )) + adj; names(out)="plhood1"
    out
  }
  
  # Execution of function
  nit <- 1
  df <- 1
  NN <- dim(Z)[1]
  value <- matrix(NA,maxit,7,dimnames=list(NULL,c("pi0","pi1","tau","sigma1","sigma2","rho","lhood")))
  value[nit,] <- c(pars,lhood(pars))
  ws = sum(weights)
  while(df>tol & nit<maxit) {
    pars0=pars 
    if ((nit %% n_save)==0) { # Print or save 'pars' every n iterations
      if (verbose) print(c(nit,pars,lhood(pars),df),digits=6)
      if (!is.null(file)) {
        hist=value[1:nit,]
        save(hist,file=tempsave)
      }
    }
    
    nit <- nit+1
    
    ## E step
    px[,1] <- lhood1(pars[1]) #lhood.single(pars[1],c(1,1),0)
    px[,2] <- lhood2(pars[2],pars[4]) #lhood.single(pars[2],c(1,pars[4]),0)
    px[,3] <- lhood3(1-pars[1]-pars[2],c(pars[3],pars[5]),pars[6])
    
    px <- px/rowSums(px) ## normalise
    if (any(!is.finite(px))) px[which(!is.finite(px))] = 0
    p <- (colSums(px*weights) + C)/(ws + 3*C)   # additional term
    pars[1]=p[1]; pars[2]=p[2]
    
    ## M step
    if (sg1) mxs=1 else mxs=0 # require fitted SDs to be >1
    
    pars[3] <- sqrt(max(mxs,sum(weights* px[,3] * Z[,1]^2 ) / sum(weights*px[,3]))) # tau
    pars[4] <- sqrt(max(mxs,sum(weights* px[,2] * Z[,2]^2 ) / sum(weights*px[,2]))) # sigma1
    
    if (!fit_null) {
      pars[5] <- sqrt(max(mxs,sum(weights* px[,3] * Z[,2]^2 ) / sum(weights*px[,3]))) # sigma2; not fit under H0
      
      tau=pars[3]; s2=pars[5]; lower=0; upper=tau*s2-0.001; # Fit rho
      if (dlhood(pars,upper/100000)<0) pars[6]=0 else {
        while (upper-lower>0.001) { # find MLE for rho using bisection method
          mid=(upper+lower)/2
          if (dlhood(pars,mid)<0) upper=mid else lower=mid
        } # endwhile
        pars[6]=(upper+lower)/2
      } # endelse
    } # endif

    if (accel & nit>5) {
      dpars=pars-pars0;
      pars1=pars; pars2=pars+dpars
      pars2[which(pars2<0)]=1e-64
      if (pars2[3]<0.5) pars2[3]=0.5;
      if (pars2[4]<0.5) pars2[4]=0.5;
      if (pars2[5]<0.5) pars2[5]=0.5;
      pars2[which(pars2[1:5]<0)]=1e-64
      if (pars2[1]+pars2[2]>1) pars2[1:2]=pars1[1:2]
      if (pars2[6]<0) pars2[6]=0
      if (pars2[6]>0.95*pars2[3]*pars2[5]) pars2[6]=0.95*pars2[3]*pars2[5] # covariance matrix must be positive definite
      while (lhood(pars2)>lhood(pars1)) {
        pars1=pars2
        pars2=pars2+(3*dpars); # pars2[6]=pars1[6]
        if (pars2[3]<0.5) pars2[3]=0.5; 
        if (pars2[4]<0.5) pars2[4]=0.5;
        if (pars2[5]<0.5) pars2[5]=0.5;
        pars2[which(pars2[1:5]<0)]=1e-64
        if (pars2[1]+pars2[2]>1) pars2[1:2]=pars1[1:2]
        if (pars2[6]<0) pars2[6]=0
        if (pars2[6]>0.95*pars2[3]*pars2[5]) pars2[6]=0.95*pars2[3]*pars2[5] # covariance matrix must be positive definite
      }
      pars=pars1
    }
    value[nit,] <- c(pars, lhood(pars))
    df <- abs(value[nit,dim(value)[2]] - value[nit-1,dim(value)[2]])
  }
  
  names(pars)=colnames(value)[1:6]
  
  if (incl_z)  yy=list(pars=pars,history=value[1:nit,],logl=value[nit,7],logl_a=lhood_a(pars),z_ad=Z,weights=weights,hypothesis=as.numeric(!fit_null)) else {
    yy=list(pars=pars,history=value[1:nit,],logl=value[nit,7],logl_a=lhood_a(pars),z_ad=NULL,weights=NULL,hypothesis=as.numeric(!fit_null))
  }
  
  class(yy)="3Gfit"
  return(yy)
}



##' Print method for class 3Gfit
##' @param yy object of class 3Gfit; generally output from fit.3g
##' @author James Liley
print.3Gfit = function(y,n=3,...) {
  cat("Fitted parameters under",c("null", "full")[1+y$hyp],"model\n")
  print(y$pars)
  cat("\n")
  cat("Pseudo-likelihood: ",y$logl)
  cat("\n")
  cat("Pseudo-likelihood of Z_a: ",y$logl_a)
  cat("\n\n")
  
  cat("Interim parameters from fitting algorithm \n")
  print(y$hist)
  cat("\n")
  if (!is.null(y$z_ad)) {
    cat("Values of Z_d, Z_a, and weights")
    print(cbind(y$z_ad,y$weights))
  } 
}




##' Summary method for class 3Gfit
##' @param yy object of class 3Gfit; generally output from fit.3g
##' @param n print this many rows of matrix
##' @author James Liley
summary.3Gfit = function(yy,n=3,...) {
  cat("Fitted parameters under",c("null", "full")[1+yy$hyp],"model\n")
  print(yy$pars)
  cat("\n")
  
  cat("Pseudo-likelihood: ",yy$logl)
  cat("\n")
  cat("Pseudo-likelihood of Z_a: ",yy$logl_a)
  cat("\n\n")
  
  cat("Number of iterations to fit:",dim(yy$hist)[1],"\n")
  if (dim(yy$hist)[1]> 2*n) {
    cat("First and final",n,"iterations of fitting algorithm\n")
   print(data.frame(yy$hist[1:n,]),row.names=FALSE)
   cat("...\n")
   print(data.frame(yy$hist[(dim(yy$hist)[1]-n+1):dim(yy$hist)[1],]),row.names=FALSE)
  } else {
    cat("Iterations of fitting algorithm")
    print(yy$hist)
  }
  cat("\n")
  if (!is.null(yy$z_ad)) {
    cat("Number of SNP observations:",dim(yy$z_ad)[1],"\n")
    cat("Number of SNPs with non-zero LDAK weights:",length(which(yy$weights>0)),"\n\n")
    cat("Max. Z_d",round(max(yy$z_ad[,1]),digits=2),"\n")
    cat("Max. Z_a",round(max(yy$z_ad[,2]),digits=2),"\n")
  } 
}



##' Plot method for class 3Gfit. If the z_ad attribute of yy is set, then plots the absolute Z_a and Z_d scores (+/+ quadrant only), blocking out dense regions, and contours of the fitted Gaussians. Note that group 3 comprises two mirror-image Gaussians. Contours for group 1 are drawn in black, group 2 in blue, and group 3 in red.
##' @param yy object of class 3Gfit; generally output from fit.3g
##' @param scales set to draw contours of the distributions at these levels (passed to plotpars and plotvdist).
##' @author James Liley

plot.3Gfit=function(yy,...) {

if (!is.null(yy$z_ad)) {
  plotZ(yy$z_ad[which(yy$weights>0),],col="darkgrey",...) 
  plotpars(yy$pars)
} else {
  plotpars(yy$pars,over=FALSE)
} 
# legend(0.6*par("usr")[2],0.8*par("usr")[4],c("Group 1","Group 2","Group 3"),col=c("black","blue","red"),lty=3)
}




##' Pseudo-likelihood for a set of observations of Z_d and Z_a
##' @param Z an n x 2 array; Z[i,1], Z[i,2] are the Z_d and Z_a scores respectively for the ith SNP
##' @param pars vector containing initial values of pi0,pi1,tau,sigma1,sigma2,rho.
##' @param weights SNP weights to adjust for LD; output from LDAK procedure
##' @param C scaling factor for adjustment
##' @param sumlog set to TRUE to return the (weighted) sum of log pseudo-likelihoods for each datapoint; FALSE to return a vector of pseudo-likelihoods for each datapoint.
##' @author James Liley
##' @return value of pseudo- log likelihood of all observations (if sumlog==TRUE) or vector of n pseudo-likelihoods (if sumlog==FALSE)

plhood <- function(Z,pars,weights=rep(1,dim(Z)[1]), sumlog=TRUE,C=1) {
  
  # various error handlers
  if ((length(dim(Z))!=2) | (dim(Z)[1]!=length(weights))) stop("Z must be an n x 2 matrix, and 'weights' must be of length n")
  if (dim(Z)[2]!=2) stop("Z must be an n x 2 matrix")
  if (length(pars)!=6) stop("Parameter 'pars' must be a six-element vector containing values of (in order) pi0, pi1, tau, sigma1, sigma2, and rho")
  if (pars[1]>=1 | pars[2]>=1 | pars[1]<=0 | pars[2]<=0 | pars[1]+pars[2]>=1) stop("Values of pi0, pi1, and pi2 (pars[1],pars[2],1-pars[1]-pars[2]) must all be between 0 and 1")
  if (min(pars[3:5])<=0 | pars[6]<0) stop("The value of rho (pars[6]) must be nonnegative and values of tau, sigma1, and sigma2 (pars[3:5]) must be positive")
  if (pars[6]>pars[3]*pars[5]) stop("The covariance matrix (sigma1^2 rho \\ rho sigma2^2) must be positive definite (rho < sigma1*sigma2)")
  
  pars=as.numeric(pars)
  ## likelihood for each group; faster having separate functions
  lhood1 =function(scale) 4*scale*exp(-rowSums(Z^2)/2)/(2*3.14159265)
  
  lhood2 =function(scale,sigma) 4*scale*exp(-(Z[,1]^2 + (Z[,2]/sigma)^2)/2)/(2*3.14159265*sigma)
  
  lhood3 <- function(scale,sigma,rho) {
    vc=rbind(c(sigma[1]^2,rho),c(rho,sigma[2]^2)); sv=solve(vc)
    vc2=rbind(c(sigma[1]^2,-rho),c(-rho,sigma[2]^2)); sv2=solve(vc2)
    2*scale*( exp(-rowSums((Z %*% sv) * Z)/2)/(2*3.14159265*sqrt(det(vc)))
              + exp(-rowSums((Z %*% sv2) * Z)/2)/(2*3.14159265*sqrt(det(vc2))))
  }
  
  e = lhood1(pars[1]) + lhood2(pars[2],pars[4]) + lhood3(1-pars[1]-pars[2],c(pars[3],pars[5]),pars[6])
  
  e[which(e==0)]=1e-64; e[which(!is.finite(e))]=1e64
  
  if(sumlog) {
    out=sum(weights*log(e)) + (C*log(pars[1]*pars[2]*(1-pars[1]-pars[2]))); names(out)="plhood"
    out 
  } else e
}



##' Computes the likelihood of Z_a alone; used for establishing how much of a likelihood ratio is because Z_a is better-fitted by a three-Gaussian model. Strictly, calculates the expected value of Z_a/Z_d when Z_a has uniform unit variance, and the parameter values tau, rho are set to 1, 0 respectively.
##'
##' @title plhood1
##' @param za one dimensional vector of Z_a scores
##' @param pars vector of parameters (pi0,pi1,tau,sigma1,sigma2,rho)
##' @param weights LDAK weights corresponding to Z_a
##' @param C scaling factor for adjustment
##' @param sumlog set to TRUE to return the (weighted) sum of log pseudo-likelihoods for each datapoint; FALSE to return a vector of pseudo-likelihoods for each datapoint.
##' @author James Liley
##' @return value of pseudo- log likelihood of all observations (if sumlog==TRUE) or vector of n pseudo-likelihoods (if sumlog==FALSE)

plhood1=function(za,pars,weights=rep(1,length(za)),C=1,sumlog=TRUE) {
  
  # various error handlers
  if ((length(dim(za))>1) | (length(za)!=length(weights))) stop("Parameter 'za' must be one-dimensional and must be of the same length as 'weights'")
  if (length(pars)!=6) stop("Parameter 'pars' must be a six-element vector containing values of (in order) pi0, pi1, tau, sigma1, sigma2, and rho")
  if (pars[1]>=1 | pars[2]>=1 | pars[1]<=0 | pars[2]<=0 | pars[1]+pars[2]>=1) stop("Values of pi0, pi1, and pi2 (pars[1],pars[2],1-pars[1]-pars[2]) must all be between 0 and 1")
  if (min(pars[3:5])<=0 | pars[6]<0) stop("The value of rho (pars[6]) must be nonnegative and values of tau, sigma1, and sigma2 (pars[3:5]) must be positive")
  if (pars[6]>pars[3]*pars[5]) stop("The covariance matrix (sigma1^2 rho \\ rho sigma2^2) must be positive definite (rho < sigma1*sigma2)")
  
  pars=as.numeric(pars)
  p=c(pars[1:2],1-pars[1]-pars[2])
  sds=c(1,pars[4:5])
  adj=C*log(prod(p))
  
  if (sumlog) {
    out=sum(weights* (
      -0.5 - (log(sqrt(2*3.1415))) + 
        log( (p[1]*dnorm(za,sd=sds[1])) + (p[2]*dnorm(za,sd=sds[2])) + (p[3]*dnorm(za,sd=sds[3])))
    )) + adj; names(out)="plhood_a"
    out
  } else {
    exp(-0.5)*(1/sqrt(2*3.1415926))*( (p[1]*dnorm(za,sd=sds[1])) + (p[2]*dnorm(za,sd=sds[2])) + (p[3]*dnorm(za,sd=sds[3])))
  }
}






##' Plots contour lines of a bivariate normal distribution parametrised by covariance matrix, at specific distribution heights 'scales'
##'
##' @title lhood
##' @param varcov covariance matrix (2D)
##' @param m mean vector
##' @param scales heights of normal pdf
##' @param over set to FALSE to draw new plot
##' @param xlim limits of x axis if over=FALSE
##' @param ylim limits of y axis if over=FALSE

plotvdist=function(varcov=diag(2), m=c(0,0), scales=(1/(6.282*det(varcov)))* (2^(-(1:5))),over=TRUE,xlim=NULL,ylim=NULL, ...) {
  
  if (!over) {
    if (is.null(xlim)) {
      xmax=sqrt(-2*(varcov[1,1]^2)*log(2*3.141592*min(scales)))
      xlim=c(-xmax,xmax)
    }
    if (is.null(ylim)) {
      ymax=sqrt(-2*(varcov[2,2]^2)*log(2*3.141592*min(scales)))
      ylim=c(-ymax,ymax)
    }
    plot(0,0,type="n",xlab=expression(paste("|Z"[d],"|")),ylab=expression(paste("|Z"[a],"|")),xaxs="i",yaxs="i",xlim=1.1*xlim,ylim=1.1*ylim,...)
  }  
  dt=det(varcov)
  yv=-2*dt*log(2*3.1415*sqrt(dt)*scales) # x sigma^-1 xT has to take these values for the pdf height to have the values 'scales'
  
  a=varcov[2,2]
  b=varcov[1,1]
  
  r=varcov[1,2];
  
  if (!(r==0)) {
    if (!(a==b)) {
      phi= 0.5*atan(2*r/(b-a)) # angle of rotation
    } else phi=3.14159/4
    ax1=a+b+(r/sin(2*phi)) # axis 1 length
    ax2=a+b-(r/sin(2*phi)) # axis 2 length
    
    c0=max(ax1,ax2); ax1=ax1/c0; ax2=ax2/c0 # normalise
    
    Q=((b-a) + sqrt((b-a)^2 + 4*r^2))/(2*r)
    dl=(Q^2+1)/(a*Q^2 - 2*Q*r + b)
    
    t=(0:100)/(2*3.141)
    rmat=rbind(c(cos(phi),-sin(phi)),c(sin(phi),cos(phi))) # rotation matrix
    
    cd= rmat %*% rbind(sqrt(dl)*ax1*sin(t),sqrt(dl)*ax2*cos(t))
    
    for (i in yv) lines(t((cd*sqrt(i)) + m),...)
    
  } else { # no covariance
    
    t=(0:100)/(2*3.141)
    
    for (i in yv) lines(cbind(sqrt(i/a)*sin(t) + m[1],sqrt(i/b)*cos(t) + m[2]),...)
    
  }
}






##' Plots contour lines of three bivariate normal distributions as determined by 'pars'
##'
##' @title plotpars
##' @param pars six element vector (pi0,pi1,tau,sigma1,sigma2,rho)

plotpars=function(pars,over=TRUE,...) {
 varcov1=diag(2)
 varcov2=cbind(c(1,0),c(0,pars[4]))
 varcov3a=cbind(c(pars[3]^2,pars[6]),c(pars[6],pars[5]^2))
 varcov3b=cbind(c(pars[3]^2,-pars[6]),c(-pars[6],pars[5]^2))

 if (!over) plot(0,0,type="n",xlim=c(-5,5),ylim=c(-5,5),xlab=expression(paste("|Z"[d],"|")),ylab=expression(paste("|Z"[a],"|")),xaxs="i",yaxs="i")
 
 plotvdist(varcov1,col="black",lty=3,over=TRUE,...)  
 plotvdist(varcov2,col="blue",lty=3,over=TRUE,...)  
 plotvdist(varcov3a,col="red",lty=3,over=TRUE,...)  
 plotvdist(varcov3b,col="red",lty=3,over=TRUE,...)  
}







##' Compute gradient of pseudo-log likelihood for a dataset at given parameters
##' @title grad_logl
##' @param Z an n x 2 array; Z[i,1], Z[i,2] are the Z_d and Z_a scores respectively for the ith SNP
##' @param pars vector containing initial values of pi0,pi1,tau,sigma1,sigma2,rho.
##' @param weights SNP weights to adjust for LD; output from LDAK procedure
##' @param C a term C*log(pi0*pi1*pi2) is added to the likelihood so the model is specified.
##' @return vector of partial derivatives of pseudo-log-likelihood with respect to each of the parameters in 'pars'
##' @export
##' @author James Liley
##' @examples
##' nn=100000
##' Z=abs(rbind(rmnorm(0.8*nn,varcov=diag(2)), rmnorm(0.15*nn,varcov=rbind(c(1,0),c(0,2^2))), rmnorm(0.05*nn,varcov=rbind(c(3^2,2),c(2,4^2))))); weights=runif(nn)
##' grad(Z,pars=c(0.7,0.2,2.5,1.5,3,1),weights=weights,C=1)
##' yy$pars
##' plot(yy,rlim=2)

grad_logl = function(Z,pars,weights=rep(0,dim(Z)[1]),C=1) {
  
  # various error handlers
  if ((length(dim(Z))!=2) | (dim(Z)[1]!=length(weights))) stop("Z must be an n x 2 matrix, and 'weights' must be of length n")
  if (dim(Z)[2]!=2) stop("Z must be an n x 2 matrix")
  if (length(pars)!=6) stop("Parameter 'pars' must be a six-element vector containing values of (in order) pi0, pi1, tau, sigma1, sigma2, and rho")
  if (pars[1]>=1 | pars[2]>=1 | pars[1]<=0 | pars[2]<=0 | pars[1]+pars[2]>=1) stop("Values of pi0, pi1, and pi2 (pars[1],pars[2],1-pars[1]-pars[2]) must all be between 0 and 1")
  if (min(pars[3:5])<=0 | pars[6]<0) stop("The value of rho (pars[6]) must be nonnegative and values of tau, sigma1, and sigma2 (pars[3:5]) must be positive")
  if (pars[6]>pars[3]*pars[5]) stop("The covariance matrix (sigma1^2 rho \\ rho sigma2^2) must be positive definite (rho < sigma1*sigma2)")
  
  pi0=pars[1]; pi1=pars[2]; pi2=1-pars[1]-pars[2]
  tau=pars[3];
  s1=pars[4]
  s2=pars[5]
  rho=pars[6]
  
  lh1=function(Z) (1/(2*3.141))*exp(-0.5*(Z[,1]^2 + Z[,2]^2))
  lh2=function(Z,s1) (1/(2*3.141*s1))*exp(-0.5*(Z[,1]^2 +(Z[,2]/s1)^2))
  lh3s=function(Z,tau,s2,rho) {
    D=((s2*tau)^2) - (rho^2)
    (1/(4*3.141*sqrt(D))) *(
      exp(-((s2*Z[,1])^2 + (tau*Z[,2])^2 - (2*rho*Z[,1]*Z[,2]) )/(2*D)) )
  } # only half of lh3;
  
  D=(tau*s2)^2 - rho^2
  l1=lh1(Z)
  l2=lh2(Z,s1)
  l3a=lh3s(Z,tau,s2,rho)
  l3b=lh3s(Z,tau,s2,-rho)
  l3=l3a+l3b
  
  ls=(pi0*l1)+(pi1*l2)+(pi2*(l3a+l3b))
  
  dpi0=sum(weights* ((l1-l3)/ls) )  + (C*(-pi0*pi1 + pi2*pi1)/(pi0*pi1*pi2)) # d(logL)/d(pi0)
  dpi1=sum(weights* ((l2-l3)/ls) ) + (C*(-pi0*pi1 + pi2*pi0)/(pi0*pi1*pi2))# d(logL)/d(pi1)
  
  ds1=sum(weights*pi[2]*l2*( ((Z[,2]^2)/(s1^3)) - (1/s1) )/ls)
  
  ds2=sum(weights*(
    pi2*l3*( - ((s2*(tau^2))/D) +
               (((s2*(tau^4)*(Z[,2]^2))+(s2*(rho^2)*(Z[,1]^2)))/(D^2))) +
      pi2*(l3b-l3a)*((2*s2*(tau^2)*rho*Z[,1]*Z[,2])/(D^2))
  )/ls)
  
  dtau=sum(weights*(
    pi2*l3*( - ((tau*(s2^2))/D) +
               (((tau*(s2^4)*(Z[,1]^2))+(tau*(rho^2)*(Z[,2]^2)))/(D^2))) +
      pi2*(l3b-l3a)*((2*tau*(s2^2)*rho*Z[,1]*Z[,2])/(D^2))
  )/ls)
  
  drho=sum(weights*(
    pi2*l3*( (rho/D) -(((tau^2)*(Z[,2]^2)*rho)/(D^2)) - (((s2^2)*(Z[,1]^2)*rho)/(D^2)) ) +
      pi2*(l3a-l3b)*( ((2*Z[,1]*Z[,2]*(rho^2))/(D^2)) + (Z[,1]*Z[,2]/D))
  )/ls )
  
  c(dpi0,dpi1,dtau,ds1,ds2,drho)
}




##' Plot Z_a and Z_d scores efficiently, blocking out dense region near origin.
##' @title plotZ
##' @param Z an n x 2 array; Z[i,1], Z[i,2] are the Z_d and Z_a scores respectively for the ith SNP
##' @param rlim block out circle of radius rlim; only plot points with Z_d^2 + Z_a^2 > rlim^2.
##' @param col colour of points or vector describing colour of each point of z_ad
##' @param mcol colour of middle blocked-out region; defaults to col[1]
##' @param abs set to TRUE to plot only upper right quadrant
##' @param over set to TRUE to plot over existing plot; FALSE to draw new plot.
##' @export
##' @author James Liley
##' @examples
##' nn=100000
##' Z=abs(rbind(rmnorm(0.8*nn,varcov=diag(2)), rmnorm(0.15*nn,varcov=rbind(c(1,0),c(0,2^2))), rmnorm(0.05*nn,varcov=rbind(c(3^2,2),c(2,4^2)))));
##' plotZ(Z,rlim=2,col="red",cex=0.5)

plotZ = function(z_ad,rlim=quantile(z_ad[,2],0.99),col=rep("black",dim(z_ad)[1]),mcol=NULL,abs=(min(z_ad)<0),over=FALSE,...) {
  require(plotrix)
  if (length(col)==1) {
    col=rep(col,dim(z_ad)[1])
  }
  
  if (is.null(mcol)) mcol=col[1]
  
  wx=which(!is.na(z_ad[,1]+z_ad[,2]))
  z_ad=z_ad[wx,]; col=col[wx]
  
  ww=which(z_ad[,1]^2 + z_ad[,2]^2 > rlim^2); nw=setdiff(1:dim(z_ad)[1],ww)
  Z=z_ad[ww,]
  if (abs) xl=expression(paste("|Z"[d],"| (between subtypes)")) else xl=expression(paste("Z"[d]," (between subtypes)"));
  if (abs) yl=expression(paste("|Z"[a],"| (case vs control)")) else yl=expression(paste("Z"[a]," (case vs control)"))
  #  if (abs) {
  #    xlim=c(0,1.05*max(Z[,1])); ylim=c(0,1.05*max(Z[,2]))
  #  } else {
  #    xlim=1.05*range(Z[,1]); ylim=1.05*range(Z[,2])
  #  }
  if (!over) {
    plot(Z,xaxs="i",yaxs="i",xlab=xl,ylab=yl,col=col[ww],...)
    draw.ellipse(0,0,rlim,rlim,col=mcol,border=mcol)
  } else {
    points(Z,col=col[ww],...)
    draw.ellipse(0,0,rlim,rlim,col=mcol,border=mcol)
  }
}


