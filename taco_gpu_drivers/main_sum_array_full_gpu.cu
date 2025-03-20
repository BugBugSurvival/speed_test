#include <cuda_runtime.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
 #include <time.h>
#include "taco.h"
extern taco_tensor_t* init_taco_tensor(int32_t order, int32_t csize, int32_t* dimensions);
extern taco_tensor_t* init_taco_tensor_gpu(taco_tensor_t* ht);
extern void fill_array(float* arr, int len);
extern double calc_spent_time(struct timespec end, struct timespec start);
extern double average(double* values, int len);
extern void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true);
#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }

#ifndef TACO_TENSOR_T_DEFINED
#define TACO_TENSOR_T_DEFINED
typedef enum { taco_mode_dense, taco_mode_sparse } taco_mode_t;
typedef struct {
  int32_t      order;         // 
  int32_t*     dimensions;    // 
  int32_t      csize;         // 
  int32_t*     mode_ordering; // 
  taco_mode_t* mode_types;    // 
  uint8_t***   indices;       // 
  float* vals          // 
  uint8_t*     fill_value;    // 
  int32_t      vals_size;     // 
} taco_tensor_t;
#endif

// Generated by the Tensor Algebra Compiler (tensor-compiler.org)

int compute(taco_tensor_t *a, taco_tensor_t *b) {
  float* __restrict__ a_vals = (float*)(a->vals);
  int b1_dimension = (int)(b->dimensions[0]);
  float* __restrict__ b_vals = (float*)(b->vals);

  float a_val = 0.0;

  for (int32_t i = 0; i < b1_dimension; i++) {
    a_val = a_val + b_vals[i];
  }

  a_vals[0] = a_val;
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
  float returnv;
  float* a = (float*)malloc(1000000 * sizeof(float));
  int n = 1000000;

  int returnv_dims[1] = {1};
  taco_tensor_t* returnv_tt = init_taco_tensor(1, sizeof(float), returnv_dims);
  returnv_tt->vals = &returnv;
  returnv_tt = init_taco_tensor_gpu(returnv_tt);
  int a_dims[1] = {1000000};
  taco_tensor_t* a_tt = init_taco_tensor(1, sizeof(float), a_dims);
  a_tt->vals = a;
  a_tt = init_taco_tensor_gpu(a_tt);

  for(int i = 0; i < n_runs; i++){
    fill_array(a, 1000000);

    clock_gettime(CLOCK_MONOTONIC, &start);
    // returnv = sum_array(a, n);
    clock_gettime(CLOCK_MONOTONIC, &end_orig);

    compute(returnv_tt, a_tt);
    clock_gettime(CLOCK_MONOTONIC, &end_taco);

    orig_run_times[i] = calc_spent_time(end_orig, start);
    taco_run_times[i] = calc_spent_time(end_taco, end_orig);
  }

  double orig_time = average(orig_run_times, n_runs);
  double taco_time = average(taco_run_times, n_runs);
  printf("%.5lf %.5lf", orig_time, taco_time);
  return 0;
}
