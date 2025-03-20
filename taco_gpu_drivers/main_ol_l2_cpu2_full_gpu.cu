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

__global__
void computeDeviceKernel0(taco_tensor_t * __restrict__ a, taco_tensor_t * __restrict__ b, taco_tensor_t * __restrict__ c){
  float* __restrict__ a_vals = (float*)(a->vals);
  float* __restrict__ b_vals = (float*)(b->vals);
  int c1_dimension = (int)(c->dimensions[0]);
  float* __restrict__ c_vals = (float*)(c->vals);

  int32_t i51 = blockIdx.x;
  int32_t i52 = (threadIdx.x % (256));
  if (threadIdx.x >= 256) {
    return;
  }

  int32_t i = i51 * 256 + i52;
  if (i >= c1_dimension)
    return;

  a_vals[i] = b_vals[i] - c_vals[i];
}

int compute(taco_tensor_t *a, taco_tensor_t *b, taco_tensor_t *c) {
  int c1_dimension = (int)(c->dimensions[0]);

  computeDeviceKernel0<<<((c1_dimension + 255) / 256), 256>>>(a, b, c);
  cudaDeviceSynchronize();
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
  int n = 1000000;
  float* pred = (float*)malloc(1000000 * sizeof(float));
  float* truth = (float*)malloc(1000000 * sizeof(float));
  float* delta = (float*)malloc(1000000 * sizeof(float));

  int pred_dims[1] = {1000000};
  taco_tensor_t* pred_tt = init_taco_tensor(1, sizeof(float), pred_dims);
  pred_tt->vals = pred;
  pred_tt = init_taco_tensor_gpu(pred_tt);
  int truth_dims[1] = {1000000};
  taco_tensor_t* truth_tt = init_taco_tensor(1, sizeof(float), truth_dims);
  truth_tt->vals = truth;
  truth_tt = init_taco_tensor_gpu(truth_tt);
  int delta_dims[1] = {1000000};
  taco_tensor_t* delta_tt = init_taco_tensor(1, sizeof(float), delta_dims);
  delta_tt->vals = delta;
  delta_tt = init_taco_tensor_gpu(delta_tt);

  for(int i = 0; i < n_runs; i++){
    fill_array(pred, 1000000);
    fill_array(truth, 1000000);
    fill_array(delta, 1000000);

    clock_gettime(CLOCK_MONOTONIC, &start);
// ol_l2_cpu2(n, pred, truth, delta);
    clock_gettime(CLOCK_MONOTONIC, &end_orig);

    compute(pred_tt, truth_tt, delta_tt);
    clock_gettime(CLOCK_MONOTONIC, &end_taco);

    orig_run_times[i] = calc_spent_time(end_orig, start);
    taco_run_times[i] = calc_spent_time(end_taco, end_orig);
  }

  double orig_time = average(orig_run_times, n_runs);
  double taco_time = average(taco_run_times, n_runs);
  printf("%.5lf %.5lf", orig_time, taco_time);
  return 0;
}
