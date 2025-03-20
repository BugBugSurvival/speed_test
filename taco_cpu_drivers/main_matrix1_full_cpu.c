
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
 #include <time.h>
#include "taco.h"
extern taco_tensor_t* init_taco_tensor(int32_t order, int32_t csize, int32_t* dimensions);

extern void fill_array(float* arr, int len);
extern double calc_spent_time(struct timespec end, struct timespec start);
extern double average(double* values, int len);



#ifndef TACO_TENSOR_T_DEFINED
#define TACO_TENSOR_T_DEFINED
typedef enum { taco_mode_dense, taco_mode_sparse } taco_mode_t;
typedef struct {
  int32_t      order;          
  int32_t*     dimensions;     
  int32_t      csize;          
  int32_t*     mode_ordering;  
  taco_mode_t* mode_types;     
  uint8_t***   indices;        
  uint8_t*     vals;           
  uint8_t*     fill_value;     
  int32_t      vals_size;      
} taco_tensor_t;
#endif

// Generated by the Tensor Algebra Compiler (tensor-compiler.org)

int compute(taco_tensor_t *a, taco_tensor_t *b, taco_tensor_t *c) {
  int a1_dimension = (int)(a->dimensions[0]);
  int a2_dimension = (int)(a->dimensions[1]);
  float* restrict a_vals = (float*)(a->vals);
  int b1_dimension = (int)(b->dimensions[0]);
  int b2_dimension = (int)(b->dimensions[1]);
  float* restrict b_vals = (float*)(b->vals);
  int c1_dimension = (int)(c->dimensions[0]);
  int c2_dimension = (int)(c->dimensions[1]);
  float* restrict c_vals = (float*)(c->vals);

  #pragma omp parallel for schedule(runtime)
  for (int32_t i = 0; i < b1_dimension; i++) {
    for (int32_t j = 0; j < c1_dimension; j++) {
      int32_t ja = i * a2_dimension + j;
      float tka_val = 0.0;
      for (int32_t k = 0; k < c2_dimension; k++) {
        int32_t kb = i * b2_dimension + k;
        int32_t kc = j * c2_dimension + k;
        tka_val += b_vals[kb] * c_vals[kc];
      }
      a_vals[ja] = tka_val;
    }
  }
  return 0;
}

int main(int argc, char* argv[]){
  int n_runs = atoi(argv[1]);
  if(argc < 2){
    printf("Please specify number of executions!\n");
    exit(1);
  }
  srand(time(0));
  struct timespec start, end_orig, end_taco;
  double* orig_run_times = (double*)malloc(n_runs * sizeof(double));
  double* taco_run_times = (double*)malloc(n_runs * sizeof(double));
  int X = 1000;
  int Y = 1000;
  int Z = 1000;
  float* A = (float*)malloc(1000 * 1000 * sizeof(float));
  float* B = (float*)malloc(1000 * 1000 * sizeof(float));
  float* C = (float*)malloc(1000 * 1000 * sizeof(float));

  int A_dims[2] = {1000,1000};
  taco_tensor_t* A_tt = init_taco_tensor(2, sizeof(float), A_dims);
  A_tt->vals = A;

  int B_dims[2] = {1000,1000};
  taco_tensor_t* B_tt = init_taco_tensor(2, sizeof(float), B_dims);
  B_tt->vals = B;

  int C_dims[2] = {1000,1000};
  taco_tensor_t* C_tt = init_taco_tensor(2, sizeof(float), C_dims);
  C_tt->vals = C;


  for(int i = 0; i < n_runs; i++){
    fill_array(A, 1000 * 1000);
    fill_array(B, 1000 * 1000);
    fill_array(C, 1000 * 1000);

    clock_gettime(CLOCK_MONOTONIC, &start);
 matrix1(X, Y, Z, A, B, C);
    clock_gettime(CLOCK_MONOTONIC, &end_orig);

    compute(C_tt, A_tt, B_tt);
    clock_gettime(CLOCK_MONOTONIC, &end_taco);

    orig_run_times[i] = calc_spent_time(end_orig, start);
    taco_run_times[i] = calc_spent_time(end_taco, end_orig);
  }

  double orig_time = average(orig_run_times, n_runs);
  double taco_time = average(taco_run_times, n_runs);
  printf("%.5lf %.5lf", orig_time, taco_time);
  return 0;
}
