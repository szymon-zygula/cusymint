#include "integral.cuh"

#include "substitution.cuh"
#include "symbol.cuh"

namespace Sym {
    std::string Integral::to_string() {
        std::string last_substitution_name;
        std::string substitutions_str;

        Symbol* symbols = Symbol::from(this) + symbols_offset;
        std::vector<Symbol> subst_symbols(symbols->unknown.total_size);
        std::copy(symbols, symbols + symbols->unknown.total_size, subst_symbols.data());

        if (substitution_count == 0) {
            last_substitution_name = "x";
        }
        else {
            last_substitution_name = Substitution::nth_substitution_name(substitution_count - 1);
            Symbol* first_substitution = Symbol::from(this) + 1;
            substitutions_str = ", " + first_substitution->to_string();

            Symbol substitute;
            substitute.unknown_constant = UnknownConstant::create(last_substitution_name.c_str());
            subst_symbols.data()->substitute_variable_with(substitute);
        }

        return "∫" + subst_symbols[0].to_string() + "d" + last_substitution_name +
               substitutions_str;
    }

    std::vector<Symbol> integral(const std::vector<Symbol>& arg) {
        std::vector<Symbol> integral(arg.size() + 1);
        integral[0].integral = Integral::create();
        integral[0].integral.total_size = 1 + arg[0].unknown.total_size;
        integral[0].integral.substitution_count = 0;
        integral[0].integral.symbols_offset = 1;
        std::copy(arg.begin(), arg.end(), integral.begin() + 1);

        return integral;
    }
}