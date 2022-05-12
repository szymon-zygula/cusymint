#include "symbol.cuh"

namespace Sym {
    __host__ __device__ void Symbol::copy_symbol_sequence(Symbol* const dst,
                                                          const Symbol* const src, size_t n) {
        Util::copy_mem(dst, src, n * sizeof(Symbol));
    }

    __host__ __device__ void
    Symbol::copy_and_reverse_symbol_sequence(Symbol* const dst, const Symbol* const src, size_t n) {
        for (size_t i = 0; i < n; ++i) {
            src[n - i - 1].copy_single_to(dst + i);
        }
    }

    __host__ __device__ bool Symbol::are_symbol_sequences_same(const Symbol* seq1,
                                                               const Symbol* seq2, size_t n) {
        // Cannot simply use Util::compare_mem because padding can differ
        for (size_t i = 0; i < n; ++i) {
            if (seq1[i] != seq2[i]) {
                return false;
            }
        }

        return true;
    }

    __host__ __device__ void Symbol::swap_symbols(Symbol* const s1, Symbol* const s2) {
        Util::swap_mem(s1, s2, sizeof(Symbol));
    }

    __host__ __device__ void Symbol::reverse_symbol_sequence(Symbol* const seq, size_t n) {
        for (size_t i = 0; i < n / 2; ++i) {
            swap_symbols(seq + i, seq + n - i - 1);
        }
    }

    __host__ __device__ void Symbol::copy_single_to(Symbol* const dst) const {
        VIRTUAL_CALL(*this, copy_single_to, dst);
    }

    __host__ __device__ void Symbol::copy_to(Symbol* const dst) const {
        Util::copy_mem(dst, this, total_size() * sizeof(Symbol));
    }

    __host__ __device__ bool Symbol::is_constant() const {
        for (size_t i = 0; i < total_size(); ++i) {
            if (this[i].is(Type::Variable)) {
                return false;
            }
        }

        return true;
    }

    __host__ __device__ ssize_t Symbol::first_var_occurence() const {
        for (size_t i = 0; i < total_size(); ++i) {
            if (this[i].is(Type::Variable)) {
                return i;
            }
        }

        return -1;
    }

    __host__ __device__ bool Symbol::is_function_of(Symbol* expression) const {
        if(is_constant()) {
            return false;
        }

        ssize_t first_var_offset = expression->first_var_occurence();

        for (size_t i = 0; i < total_size(); ++i) {
            if (this[i].is(Type::Variable)) {
                // First variable in `this` appears earlier than first variable in `expression` or
                // `this` is not long enough to contain another occurence of `expression`
                if (i < first_var_offset ||
                    total_size() - i < expression->total_size() - first_var_offset) {
                    return false;
                }

                if (!are_symbol_sequences_same(this + i - first_var_offset, expression,
                                               expression->total_size())) {
                    return false;
                }

                i += expression->total_size() - first_var_offset - 1;
            }
        }

        return true;
    }

    __host__ __device__ void
    Symbol::substitute_with_var_with_holes(Symbol* const destination,
                                           const Symbol* const expression) const {
        ssize_t first_var_offset = expression->first_var_occurence();
        copy_to(destination);

        for (size_t i = 0; i < total_size(); ++i) {
            if (destination[i].is(Type::Variable)) {
                destination[i - first_var_offset].variable = Variable::create();
                i += expression->total_size() - first_var_offset - 1;
            }
        }
    }

    __host__ __device__ size_t Symbol::compress_reverse_to(Symbol* const destination) const {
        return VIRTUAL_CALL(*this, compress_reverse_to, destination);
    }

    void Symbol::substitute_variable_with(const Symbol symbol) {
        for (size_t i = 0; i < total_size(); ++i) {
            if (this[i].is(Type::Variable)) {
                this[i] = symbol;
            }
        }
    }

    std::string Symbol::to_string() const { return VIRTUAL_CALL(*this, to_string); }

    __host__ __device__ bool operator==(const Symbol& sym1, const Symbol& sym2) {
        return VIRTUAL_CALL(sym1, compare, &sym2);
    }

    __host__ __device__ bool operator!=(const Symbol& sym1, const Symbol& sym2) {
        return !(sym1 == sym2);
    }
};
