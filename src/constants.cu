#include "constants.cuh"

#include "symbol.cuh"

namespace Sym {
    std::string KnownConstant::to_string() {
        switch (value) {
        case KnownConstantValue::E:
            return "e";
        case KnownConstantValue::Pi:
            return "π";
        case KnownConstantValue::Unknown:
        default:
            return "<Undefined known constant>";
        }
    }

    std::vector<Symbol> known_constant(KnownConstantValue value) {
        std::vector<Symbol> v(1);
        v[0].known_constant = KnownConstant::create();
        v[0].known_constant.value = value;
        return v;
    }

    std::vector<Symbol> e() { return known_constant(KnownConstantValue::E); }

    std::vector<Symbol> pi() { return known_constant(KnownConstantValue::Pi); }

    std::vector<Symbol> cnst(const char name[UnknownConstant::NAME_LEN]) {
        std::vector<Symbol> v(1);
        v[0].unknown_constant = UnknownConstant::create();
        std::copy(name, name + UnknownConstant::NAME_LEN, v[0].unknown_constant.name);
        return v;
    }

    std::vector<Symbol> num(double value) {
        std::vector<Symbol> v(1);
        v[0].numeric_constant = NumericConstant::create();
        v[0].numeric_constant.value = value;
        return v;
    }
} // namespace Sym
