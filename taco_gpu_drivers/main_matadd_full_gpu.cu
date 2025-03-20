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
  int a2_dimension = (int)(a->dimensions[1]);
  float* __restrict__ a_vals = (float*)(a->vals);
  int b2_dimension = (int)(b->dimensions[1]);
  float* __restrict__ b_vals = (float*)(b->vals);
  int c1_dimension = (int)(c->dimensions[0]);
  int c2_dimension = (int)(c->dimensions[1]);
  float* __restrict__ c_vals = (float*)(c->vals);

  int32_t i73 = blockIdx.x;
  int32_t i74 = (threadIdx.x % (256));
  if (threadIdx.x >= 256) {
    return;
  }

  int32_t i = i73 * 256 + i74;
  if (i >= c1_dimension)
    return;

  for (int32_t j = 0; j < c2_dimension; j++) {
    int32_t ja = i * a2_dimension + j;
    int32_t jb = i * b2_dimension + j;
    int32_t jc = i * c2_dimension + j;
    a_vals[ja] = b_vals[jb] + c_vals[jc];
  }
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
  float* matA = (float*)malloc(1000 * 1000 * sizeof(float));
  float* matB = (float*)malloc(1000 * 1000 * sizeof(float));
  int m = 1000;
  int n = 1000;

  int matA_dims[2] = {1000,1000};
  taco_tensor_t* matA_tt = init_taco_tensor(2, sizeof(float), matA_dims);
  matA_tt->vals = matA;
  matA_tt = init_taco_tensor_gpu(matA_tt);
  int matB_dims[2] = {1000,1000};
  taco_tensor_t* matB_tt = init_taco_tensor(2, sizeof(float), matB_dims);
  matB_tt->vals = matB;
  matB_tt = init_taco_tensor_gpu(matB_tt);

  for(int i = 0; i < n_runs; i++){
    fill_array(matA, 1000 * 1000);
    fill_array(matB, 1000 * 1000);

    clock_gettime(CLOCK_MONOTONIC, &start);
// matadd(matA, matB, m, n);
    clock_gettime(CLOCK_MONOTONIC, &end_orig);

    compute(matA_tt, matA_tt, matB_tt);
    clock_gettime(CLOCK_MONOTONIC, &end_taco);

    orig_run_times[i] = calc_spent_time(end_orig, start);
    taco_run_times[i] = calc_spent_time(end_taco, end_orig);
  }

  double orig_time = average(orig_run_times, n_runs);
  double taco_time = average(taco_run_times, n_runs);
  printf("%.5lf %.5lf", orig_time, taco_time);
  return 0;
}
