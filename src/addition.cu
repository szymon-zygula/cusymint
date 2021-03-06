
#include "addition.cuh"

#include "TreeIterator.cuh"
#include "cuda_utils.cuh"
#include "symbol.cuh"

namespace Sym {
    DEFINE_TWO_ARGUMENT_COMMUTATIVE_OP_FUNCTIONS(Addition)
    DEFINE_SIMPLE_ONE_ARGUMETN_OP_COMPARE(Addition)
    DEFINE_TWO_ARGUMENT_OP_COMPRESS_REVERSE_TO(Addition)

    DEFINE_SIMPLIFY_IN_PLACE(Addition) {
        arg1().simplify_in_place(help_space);
        arg2().simplify_in_place(help_space);

        simplify_structure(help_space);
        simplify_pairs();
        eliminate_zeros();
    }

    __host__ __device__ bool Addition::is_sine_cosine_squared_sum(const Symbol* const expr1,
                                                                  const Symbol* const expr2) {
        bool is_expr1_sine_squared = expr1->is(Type::Power) && expr1->power.arg1().is(Type::Sine) &&
                                     expr1->power.arg1().sine.arg().is(Type::Variable) &&
                                     expr1->power.arg2().is(Type::NumericConstant) &&
                                     expr1->power.arg2().numeric_constant.value == 2.0;

        bool is_expr2_cosine_squared = expr2->is(Type::Power) &&
                                       expr2->power.arg1().is(Type::Cosine) &&
                                       expr2->power.arg1().cosine.arg().is(Type::Variable) &&
                                       expr2->power.arg2().is(Type::NumericConstant) &&
                                       expr2->power.arg2().numeric_constant.value == 2.0;

        return is_expr1_sine_squared && is_expr2_cosine_squared;
    }

    __host__ __device__ bool Addition::are_equal_of_opposite_sign(const Symbol* const expr1,
                                                                  const Symbol* const expr2) {
        return expr1->is(Type::Negation) && Symbol::compare_trees(&expr1->negation.arg(), expr2) ||
               expr2->is(Type::Negation) && Symbol::compare_trees(&expr2->negation.arg(), expr1);
    }

    DEFINE_TRY_FUSE_SYMBOLS(Addition) {
        // Sprawdzenie, czy jeden z argumentów nie jest rónwy zero jest wymagane by nie wpaść w
        // nieskończoną pętlę, zera i tak są potem usuwane w `eliminate_zeros`.
        if (expr1->is(Type::NumericConstant) && expr2->is(Type::NumericConstant) &&
            expr1->numeric_constant.value != 0.0 && expr2->numeric_constant.value != 0.0) {
            expr1->numeric_constant.value += expr2->numeric_constant.value;
            expr2->numeric_constant.value = 0.0;
            return true;
        }

        if (are_equal_of_opposite_sign(expr1, expr2)) {
            expr1->numeric_constant = NumericConstant::with_value(0.0);
            expr2->numeric_constant = NumericConstant::with_value(0.0);
            return true;
        }

        // TODO: Jakieś inne tożsamości trygonometryczne
        // TODO: Rozszerzyć na kombinacje liniowe, np x*sin^2(x) + x*cos^2(x) = x
        if (is_sine_cosine_squared_sum(expr1, expr2) || is_sine_cosine_squared_sum(expr2, expr1)) {
            expr1->numeric_constant = NumericConstant::with_value(1.0);
            expr2->numeric_constant = NumericConstant::with_value(0.0);
            return true;
        }

        // TODO: Dodawanie gdy to samo jest tylko przemnożone przez stałą
        // TODO: Jedynka hiperboliczna gdy funkcje hiperboliczne będą już zaimplementowane

        return false;
    }

    __host__ __device__ void Addition::eliminate_zeros() {
        if (arg1().is(Type::Addition)) {
            arg1().addition.eliminate_zeros();
        }

        if (arg2().is(Type::NumericConstant) && arg2().numeric_constant.value == 0.0) {
            arg1().copy_to(this_symbol());
            return;
        }

        if (arg1().is(Type::NumericConstant) && arg1().numeric_constant.value == 0.0) {
            arg2().copy_to(this_symbol());
        }
    }

    DEFINE_ONE_ARGUMENT_OP_FUNCTIONS(Negation)
    DEFINE_SIMPLE_ONE_ARGUMETN_OP_COMPARE(Negation)
    DEFINE_ONE_ARGUMENT_OP_COMPRESS_REVERSE_TO(Negation)

    DEFINE_SIMPLIFY_IN_PLACE(Negation) {
        arg().simplify_in_place(help_space);

        if (arg().is(Type::Negation)) {
            arg().negation.arg().copy_to(this_symbol());
            return;
        }

        if (arg().is(Type::NumericConstant)) {
            *this_as<NumericConstant>() =
                NumericConstant::with_value(-arg().numeric_constant.value);
        }
    }

    std::string Addition::to_string() const {
        if (arg2().is(Type::Negation)) {
            return "(" + arg1().to_string() + "-" + arg2().negation.arg().to_string() + ")";
        }
        else if (arg2().is(Type::NumericConstant) && arg2().numeric_constant.value < 0.0) {
            return "(" + arg1().to_string() + "-" + std::to_string(-arg2().numeric_constant.value) +
                   ")";
        }
        else {
            return "(" + arg1().to_string() + "+" + arg2().to_string() + ")";
        }
    }

    std::string Negation::to_string() const { return "-" + arg().to_string(); }

    std::vector<Symbol> operator+(const std::vector<Symbol>& lhs, const std::vector<Symbol>& rhs) {
        std::vector<Symbol> res(lhs.size() + rhs.size() + 1);
        Addition::create(lhs.data(), rhs.data(), res.data());
        return res;
    }

    std::vector<Symbol> operator-(const std::vector<Symbol>& arg) {
        std::vector<Symbol> res(arg.size() + 1);
        Negation::create(arg.data(), res.data());
        return res;
    }

    std::vector<Symbol> operator-(const std::vector<Symbol>& lhs, const std::vector<Symbol>& rhs) {
        return lhs + (-rhs);
    }

}
