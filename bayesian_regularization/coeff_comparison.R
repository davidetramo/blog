
# Bayesian Models for Regularization --------------------------------------


# Packages ----------------------------------------------------------------
library(dplyr)
library(ggplot2) # contains the diamonds dataset
library(brms)
library(parallel)

source("generalized_ridge_point_estimator.R")
source("brms_models.R")
source("utils.R")

# for faster bayesian models
options(mc.cores = parallel::detectCores())

# Set up X & y ----------------------------------------------

# Let's choose a small sample to better see the impact of
# the prior relative to the data

set.seed(123)
sample_fraction <- 0.07

df <- sample_frac(
  tbl = diamonds, 
  size = sample_fraction
)

df <- select_if(
  .tbl = df,
  .predicate = is.numeric
)

train_rows <- sample(nrow(df), nrow(df) * 0.7)

df_train <- df[train_rows,]
df_test <- df[-train_rows,]

# Train matrices --------------------------------------------------------------
y <- df_train %>% 
  dplyr::select("price") %>% 
  as.matrix()

X <- df_train %>% 
  dplyr::select(-"price") %>% 
  as.matrix()

X <- cbind(1, X)


# Test matrices ---------------------------------------------------------------
X_new <- df_test %>% 
  dplyr::select(-"price") %>% 
  as.matrix()

y_new <- df_test %>% 
  dplyr::select("price") %>% 
  as.matrix()

X_new <- cbind(1, X_new)

# Generalized ridge estimator ---------------------------------------------

# OLS Sanity check --------------------------------------------------------

# sanity check that ols and ridge are the same
# when penalty parameters are set to zero!

# regularization parameters
lambda <- 0
mu <- rep(0, ncol(X))

sanity_check <- gen_ridge(
  X = X,
  y = y,
  lambda = lambda,
  mu = mu
)

# compute ols coefficients
ols_res <- summary(lm(price ~., data = df_train))$coefficients[,"Estimate"]
ols_res <- data.frame(
  var_name = names(ols_res),
  coef = ols_res
)

# join
sanity_check <- sanity_check %>% 
  dplyr::left_join(ols_res, by = "var_name") %>% 
  dplyr::rename(ridge = coef.x, ols = coef.y)

# Proper specfication -----------------------------------------------------

# with mu = 0
res_1 <- lambda_iterator(
  X = X,
  y = y,
  mu = rep(0, ncol(X)),
  max_lambda = 50000
)

plot1 <- res_1 %>% 
  dplyr::filter(var_name != "(Intercept)") %>% 
  penalty_plot() + 
  ggtitle("No prior (mu = 0)")

# with meaningfully specified mu != 0
mu_param <- c(4000, 2000, -500, -1000, -4000, 1000, -500)

res_2 <- lambda_iterator(
  X = X,
  y = y,
  mu = mu_param,
  max_lambda = 50000
)

plot2 <- res_2 %>% 
  dplyr::filter(var_name != "(Intercept)") %>% 
  penalty_plot() +
  ggtitle("Meaningful prior")

tiff(filename = "penalty_plots.tiff", res = 120, width = 1400, height = 700)
gridExtra::grid.arrange(
  plot1, plot2, nrow = 2
)
dev.off()

# Bayesian model parameters -------------------------------------------------------------

lambdas_inv <- rev(seq(
  from = 1,
  to = 5000,
  by = 100
))

prior_params <- c(
  "carat" = 2000,
  "depth" = -500,
  "table" = -1000,
  "x" = -4000,
  "y" = -1000,
  "z" = -500
)

prior_params_zero <- c(
  "carat" = 0,
  "depth" = 0,
  "table" = 0,
  "x" = 0,
  "y" = 0,
  "z" = 0
)


# Run models --------------------------------------------------------------

res_bayes <- bayes_wrapper(
  df = df_train,
  prior_params = prior_params,
  lambdas_inv = lambdas_inv
)

res_bayes_ref <- bayes_wrapper(
  df = df_train,
  prior_params = prior_params,
  lambdas_inv = lambdas_inv
)


# Visualize change in estimates -------------------------------------------

bayes_plot_prior <- res_bayes %>% 
  dplyr::filter(var_name != "Intercept") %>% 
  ggplot(aes(x = log(1/lambda), y = coef, color = var_name)) +
  geom_line() + theme_minimal() +
  labs(color = "", y = "Coefficient", x = "log(1/Lambda)", 
       title = "Non-zero prior mean")

bayes_plot_no_prior <- res_bayes_ref %>% 
  dplyr::filter(var_name != "Intercept") %>% 
  ggplot(aes(x = log(1/lambda), y = coef, color = var_name)) +
  geom_line() + theme_minimal() + 
  labs(color = "", y = "Coefficient", x = "log(1/Lambda)", 
       title = "Zero prior mean")

# save image
tiff(filename = "bayes_penalty_plots.tiff", res = 120, width = 1400, height = 700)
gridExtra::grid.arrange(
  bayes_plot_no_prior, bayes_plot_prior, nrow = 2
)
dev.off()


