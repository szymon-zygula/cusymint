#ifndef PRODUCT_CUH
#define PRODUCT_CUH

#include <vector>

#include "symbol_defs.cuh"

namespace Sym {
    DECLARE_SYMBOL(Product, false)
    TWO_ARGUMENT_COMMUTATIVE_OP_SYMBOL(Product)
    std::string to_string() const;

  private:
    /*
     * @brief W drzewie mnożenia usuwa mnożenia, których jednym z argumentów jest 1.0. Mnożenie
     * takie jest zamieniane na niejedynkowy argument lub 1.0, jeśli oba argumenty były jedynką.
     * Pozostawia drzewo z niekoherentnymi rozmiarami (wymaga wywołania compress_reverse_to).
     * UWAGA: funkcja ta może zmienić typ `this`, np. kiedy `this == * Reciprocal(pi) pi`, to po
     * wykonaniu funkcji `this == 1.0`, czyli typ się zmienił z Product na NumericConstant! Nie
     * należy więc po wywołaniu tej funkcji wywoływać już żadnych innych funkcji składowych z
     * Product!
     */
    __host__ __device__ void eliminate_ones();

    /*
     * @brief Sprawdza, czy `expr1` i `expr2` są swoimi odwrotnościami.
     *
     * @param expr1 Pierwsze wyrażenie
     * @param expr2 Drugie wyrażenie
     *
     * @return `true` jeśli `expr1 == 1/expr2`, `false` w przeciwnym wypadku
     */
    __host__ __device__ static bool are_inverse_of_eachother(const Symbol* const expr1,
                                                             const Symbol* const expr2);
    END_DECLARE_SYMBOL(Product)

    DECLARE_SYMBOL(Reciprocal, false)
    ONE_ARGUMENT_OP_SYMBOL

    std::string to_string() const;
    END_DECLARE_SYMBOL(Reciprocal)

    std::vector<Symbol> operator*(const std::vector<Symbol>& lhs, const std::vector<Symbol>& rhs);
    std::vector<Symbol> operator/(const std::vector<Symbol>& lhs, const std::vector<Symbol>& rhs);
}

#endif
