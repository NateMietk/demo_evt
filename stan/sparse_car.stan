data {
    int n;                  // number of regions
    int p;                  // number of coefficients
    int y[n];               // observed cases
    matrix[n, p] X;          // design matrix
    vector[n] log_offset;   // expected cases
    int W_n;                // number of adjacent region pairs
    int W1[W_n];            // first half of adjacency pairs
    int W2[W_n];            // second half of adjacency pairs
    vector[n] D_sparse;     // diagonal (sum_cij)
    vector[n] lambda;       // eigenvalues of invsqrtD * W * invsqrtD
}

parameters {
  vector[p] beta;         // coefficients
  vector[n] phi;        // area-specific random effect (CAR)
  real<lower = 0> tau;   // precision of CAR
  real<lower = 0, upper = 1> alpha;// strength of spatial correlation
}
model {
  // tmp variables for MVn likelihood
  row_vector[n] phit_D; // phi' * D
  row_vector[n] phit_W; // phi' * W
  vector[n] ldet_terms;

  // priors on model parameters
  beta ~ normal(-20, 5);
  tau ~ normal(0, 1);

  // CAR model using sparse MVn
  // (phi' * Tau * phi) can be calculated as (phi' * D * phi) - alpha * (phi' * W * phi)
  // and each of those can benefit from a sparse representation

  // find phi' * D
  phit_D = (phi .* D_sparse)';

  // find phi' * W
  phit_W = rep_vector(0.0, n)';    // initialize vector
  for (i in 1:W_n) {
    phit_W[W1[i]] = phit_W[W1[i]] + phi[W2[i]];
    phit_W[W2[i]] = phit_W[W2[i]] + phi[W1[i]];
  }

  for (i in 1:n) ldet_terms[i] = log1m(alpha * lambda[i]); // determinant
  target += 0.5 * n * log(tau)
          + 0.5 * sum(ldet_terms)
          - 0.5 * tau * (dot_product(phit_D, phi) - alpha * (phit_W * phi));

  y ~ poisson_log(X * beta + phi + log_offset);
}
generated quantities {
  vector[n] log_mu;
  log_mu = X * beta + phi + log_offset;
}
