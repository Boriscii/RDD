
library('wooldridge')
library('xgboost')
library('ROCR')
library(tidyverse)
library(ggplot2)
library(progress)
library('rdd')
library('aciccomp2016')


head(input_2016)
data(alcohol)

set.seed(350)
alco <- alcohol[sample(1:nrow(alcohol)), ]

outcome_col <- alco$employ
treatment_status <- alco$abuse

outcome_stripped <- alco %>%
  select(-c('status', 'inwf', 'employ'))

treatment_stripped <- outcome_stripped %>%
  select(-c('abuse'))

treatment_labels <- alco$abuse

set <- data.matrix(treatment_stripped)
n_train <- round(length(treatment_labels) * .7)


train_data <- set[1:n_train,]
train_labels <- treatment_labels[1:n_train]

test_data <- set[-(1:n_train),]
test_labels <- treatment_labels[(n_train + 1):length(treatment_labels)]


dtrain <- xgb.DMatrix(data = train_data, label= train_labels)
dval <- xgb.DMatrix(data = test_data, label= test_labels)


# specify validation set monitoring during training
watchlist<-list(train=dtrain)

# set parameters 
param <- list(  objective           = "binary:logistic", 
                booster             = "gbtree",
                eval_metric         = "logloss",
                eta                 = 0.01,      #low eta (learning rate) value means model more robust to overfitting but slower to compute
                max_depth           = 12,        # max depth of tree
                subsample           = 0.97,      #ratio of the training instance
                colsample_bytree    = 0.6,       #subsample ratio of columns when constructing tree
                min_child_weight    = 1,         #minimum sum of instance weight needed in a child. The larger, the more conservative the algorithm.
                num_parallel_tree   = 1          #number of trees to grow per round 
)


# number of rounds: can change <1500
nrounds <- 1500
early.stop.round <- 300

# Fit XGB model
model <- xgb.train( params              = param, 
                    data                = dtrain, 
                    nrounds             = nrounds, 
                    verbose             = 1,
                    print_every_n       = 20,
                    early_stop_round    = early.stop.round,
                    watchlist           = watchlist,
                    maximize            = FALSE  #minimize log loss score
)

inputs <- c("nrounds"=model$bestInd,
            "eta"=param$eta,
            "max_depth"=param$max_depth,
            "subsample"=param$subsample,
            "colsample_bytree"=param$colsample_bytree,
            "min_child_weight"=param$min_child_weight,
            "num_parallel_tree"=param$num_parallel_tree)

#variable importance
imp <- xgb.importance(model = model)

#calculate logloss
MultiLogLoss <- function(act, pred)
{
  eps = 1e-15;
  nr <- nrow(pred)
  pred = matrix(sapply( pred, function(x) max(eps,x)), nrow = nr)      
  pred = matrix(sapply( pred, function(x) min(1-eps,x)), nrow = nr)
  ll = sum(act*log(pred) + (1-act)*log(1-pred))
  ll = ll * -1/(nrow(act))      
  return(ll);
}

supervisedpred <- predict(model, data.matrix(test_data), ntreelimit=model$bestInd)

pred.mat <- as.matrix(cbind(supervisedpred,supervisedpred))

act.mat <- as.matrix(cbind(test_labels,test_labels))

MultiLogLoss(act.mat, pred.mat)

perf.pred <- prediction(supervisedpred,test_labels)
perf <- performance(perf.pred, "acc")
plot(perf)


PS_labels <- predict(model, data.matrix(treatment_stripped), ntreelimit=model$bestInd)

matched_sample <- treatment_stripped %>% 
                  add_column(PS = PS_labels) %>% 
                  add_column(outcome = outcome_col) %>% 
                  add_column(treatment = treatment_status) %>% 
                  arrange(PS) 
      

## I know that this way to search for the threshold is N(O^2) and inefficient but I think
## that this is justified given how important is the threshold value. I experimented
## with some forms of clustering and while Agglomerative Clustering with 
## min intra-group distance (linkage = 'single') delivers broadly good results
## I still prefer the guranteed naive solution

max_dist <- 0
threshold <- 0
cutoffs <- 100
treatment_line <- data.frame(PS = PS_labels, treatment = treatment_status) %>% 
                  arrange(treatment = PS)

pb <- progress_bar$new(total = nrow(treatment_line) - cutoffs * 2 + 4)


for (row in cutoffs:(nrow(treatment_line) - cutoffs)) {
    crossgroup_diff <- mean(treatment_line[1:row, 'treatment'], na.rm=TRUE) - mean(treatment_line[row+1:nrow(treatment_line), 'treatment'], na.rm=TRUE)
    pb$tick()
    
    
    if (is.na(crossgroup_diff)){
      next
    }
    if (abs(crossgroup_diff) > max_dist) {
      max_dist <- crossgroup_diff
      threshold <- treatment_line[row, 'PS']
    }
    
    
}

bw = IKbandwidth(X = matched_sample$PS, Y = matched_sample$outcome, cutpoint = threshold)


rdd <- RDestimate(outcome ~ PS, matched_sample, cutpoint = threshold, bw = bw,
                verbose = TRUE, model = TRUE)


summary(rdd)

