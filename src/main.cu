#include <cstdlib>
#include <cstring>

#include <iostream>
#include <vector>

#include <thrust/execution_policy.h>
#include <thrust/scan.h>

#include "integral.cuh"
#include "integrate.cuh"
#include "symbol.cuh"

static constexpr size_t BLOCK_SIZE = 512;
static constexpr size_t BLOCK_COUNT = 32;

void check_and_apply_heuristics(Sym::Symbol*& d_integrals, Sym::Symbol*& d_integrals_swap,
                                Sym::Symbol* d_swap_spaces, size_t* d_integral_count,
                                size_t* d_applicability) {
    std::cout << "Checking heuristics" << std::endl;

    cudaDeviceSynchronize();

    Sym::check_heuristics_applicability<<<BLOCK_COUNT, BLOCK_SIZE>>>(d_integrals, d_applicability,
                                                                     d_integral_count);

    cudaDeviceSynchronize();

    std::cout << "Calculating partial sum of applicability" << std::endl;

    thrust::inclusive_scan(thrust::device, d_applicability,
                           d_applicability + Sym::APPLICABILITY_ARRAY_SIZE, d_applicability);

    std::cout << "Applying heuristics" << std::endl;

    cudaDeviceSynchronize();

    Sym::apply_heuristics<<<BLOCK_COUNT, BLOCK_SIZE>>>(d_integrals, d_integrals_swap, d_swap_spaces,
                                                       d_applicability, d_integral_count);
    std::swap(d_integrals, d_integrals_swap);
    cudaMemcpy(d_integral_count, d_applicability + Sym::APPLICABILITY_ARRAY_SIZE - 1,
               sizeof(size_t), cudaMemcpyDeviceToDevice);

    std::cout << std::endl;
}

void print_current_results(size_t* d_applicability, Sym::Symbol* d_integrals,
                           size_t* d_integral_count) {
    std::cout << "Copying results to host memory" << std::endl;

    std::vector<size_t> h_applicability(Sym::APPLICABILITY_ARRAY_SIZE);
    cudaMemcpy(h_applicability.data(), d_applicability,
               Sym::APPLICABILITY_ARRAY_SIZE * sizeof(size_t), cudaMemcpyDeviceToHost);

    std::vector<Sym::Symbol> h_results(Sym::INTEGRAL_ARRAY_SIZE);
    cudaMemcpy(h_results.data(), d_integrals, Sym::INTEGRAL_ARRAY_SIZE * sizeof(Sym::Symbol),
               cudaMemcpyDeviceToHost);
    size_t h_integral_count;
    cudaMemcpy(&h_integral_count, d_integral_count, sizeof(size_t), cudaMemcpyDeviceToHost);

    std::cout << "Applicability:" << std::endl;
    for (size_t i = 0; i < h_applicability.size(); ++i) {
        if (i % Sym::MAX_INTEGRAL_COUNT == 0 && i != 0) {
            std::cout << std::endl;
        }

        std::cout << h_applicability[i] << ", ";
    }
    std::cout << std::endl;

    std::cout << "Results (" << h_integral_count << "):" << std::endl;
    for (size_t i = 0; i < h_integral_count; ++i) {
        std::cout << h_results[i * Sym::INTEGRAL_MAX_SYMBOL_COUNT].to_string() << std::endl;
    }
}

int main() {
    std::cout << "Testing manual substitutions" << std::endl;
    std::vector<Sym::Symbol> ixpr = Sym::integral(Sym::var() ^ Sym::num(2));
    std::cout << "ixpr1: " << ixpr[0].to_string() << std::endl;

    std::vector<Sym::Symbol> ixpr2 = Sym::substitute(ixpr, Sym::cos(Sym::var()));
    std::cout << "ixpr2: " << ixpr2[0].to_string() << std::endl;

    std::vector<Sym::Symbol> ixpr3 = Sym::substitute(ixpr2, Sym::var() * (Sym::e() ^ Sym::var()));
    std::cout << "ixpr3: " << ixpr3[0].to_string() << std::endl;

    std::cout << std::endl;
    std::cout << "Creating integrals" << std::endl;

    std::vector<std::vector<Sym::Symbol>> integrals = {
        Sym::integral(Sym::cos(Sym::var())),
        Sym::integral(Sym::sin(Sym::cos(Sym::var()))),
        Sym::integral(Sym::e() ^ Sym::var()),
        Sym::integral((Sym::e() ^ Sym::var()) * (Sym::e() ^ Sym::var())),
        Sym::integral(Sym::var() ^ Sym::num(5)),
        Sym::integral(Sym::var() ^ (Sym::pi() + Sym::num(1))),
        Sym::integral(Sym::var() ^ Sym::var()),
        Sym::integral(Sym::pi() + Sym::e() * Sym::num(10)),
        Sym::integral((Sym::e() ^ Sym::var()) * (Sym::e() ^ (Sym::e() ^ Sym::var())))};

    for (size_t i = 0; i < integrals.size(); ++i) {
        std::cout << integrals[i][0].to_string() << std::endl;
    }

    std::cout << std::endl;
    std::cout << "Allocating and zeroing GPU memory" << std::endl;

    size_t mem_total = 0;

    Sym::Symbol* d_integrals;
    cudaMalloc(&d_integrals, Sym::INTEGRAL_ARRAY_SIZE * sizeof(Sym::Symbol));
    cudaMemset(d_integrals, 0, Sym::INTEGRAL_ARRAY_SIZE * sizeof(Sym::Symbol));
    mem_total += Sym::INTEGRAL_ARRAY_SIZE * sizeof(Sym::Symbol);

    Sym::Symbol* d_integrals_swap;
    cudaMalloc(&d_integrals_swap, Sym::INTEGRAL_ARRAY_SIZE * sizeof(Sym::Symbol));
    mem_total += Sym::INTEGRAL_ARRAY_SIZE * sizeof(Sym::Symbol);

    Sym::Symbol* d_swap_spaces;
    cudaMalloc(&d_swap_spaces, Sym::INTEGRAL_ARRAY_SIZE * sizeof(Sym::Symbol));
    mem_total += Sym::INTEGRAL_ARRAY_SIZE * sizeof(Sym::Symbol);

    size_t* d_applicability;
    cudaMalloc(&d_applicability, Sym::APPLICABILITY_ARRAY_SIZE * sizeof(size_t));
    cudaMemset(d_applicability, 0, Sym::APPLICABILITY_ARRAY_SIZE * sizeof(size_t));
    mem_total += Sym::APPLICABILITY_ARRAY_SIZE * sizeof(size_t);

    size_t h_integral_count = integrals.size();
    size_t* d_integral_count;
    cudaMalloc(&d_integral_count, sizeof(size_t));
    mem_total += sizeof(size_t);

    std::cout << "Allocated " << mem_total << " bytes (" << mem_total / 1024 / 1024 << "MiB)"
              << std::endl;

    std::cout << "Copying to GPU memory" << std::endl;

    cudaMemcpy(d_integral_count, &h_integral_count, sizeof(size_t), cudaMemcpyHostToDevice);
    for (size_t i = 0; i < integrals.size(); ++i) {
        cudaMemcpy(d_integrals + Sym::INTEGRAL_MAX_SYMBOL_COUNT * i, integrals[i].data(),
                   integrals[i].size() * sizeof(Sym::Symbol), cudaMemcpyHostToDevice);
    }

    std::cout << std::endl;

    check_and_apply_heuristics(d_integrals, d_integrals_swap, d_swap_spaces, d_integral_count,
                               d_applicability);
    print_current_results(d_applicability, d_integrals, d_integral_count);

    cudaMemset(d_applicability, 0, Sym::APPLICABILITY_ARRAY_SIZE * sizeof(size_t));

    check_and_apply_heuristics(d_integrals, d_integrals_swap, d_swap_spaces, d_integral_count,
                               d_applicability);
    print_current_results(d_applicability, d_integrals, d_integral_count);

    std::cout << "Freeing GPU memory" << std::endl;
    cudaFree(d_applicability);
    cudaFree(d_integrals_swap);
    cudaFree(d_integrals);
}
