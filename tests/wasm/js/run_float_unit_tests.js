import { print_i63, print_bool, print_prod, print_float, print_float_comparison, print_float_class } from './modules/pp.js';

/* Expected values are those of Rocq's kernel, rendered by the printers
   in modules/pp.js. See float_unit_tests.v. */

const tests = [
    ["add1", print_float, "5"],
    ["add2", print_float, "0.75"],
    ["add3", print_float, "0.30000000000000004"],
    ["add4", print_float, "nan"],
    ["add5", print_float, "nan"],
    ["add6", print_float, "0"],
    ["sub1", print_float, "1"],
    ["sub2", print_float, "-0.5"],
    ["sub3", print_float, "0"],
    ["sub4", print_float, "nan"],
    ["mul1", print_float, "6"],
    ["mul2", print_float, "0.25"],
    ["mul3", print_float, "nan"],
    ["mul4", print_float, "-0"],
    ["div1", print_float, "2"],
    ["div2", print_float, "infinity"],
    ["div3", print_float, "neg_infinity"],
    ["div4", print_float, "nan"],
    ["div5", print_float, "0.3333333333333333"],
    ["sqrt1", print_float, "2"],
    ["sqrt2", print_float, "1.4142135623730951"],
    ["sqrt3", print_float, "nan"],
    ["sqrt4", print_float, "0"],
    ["sqrt5", print_float, "-0"],
    ["opp1", print_float, "-1.5"],
    ["opp2", print_float, "-0"],
    ["opp3", print_float, "infinity"],
    ["abs1", print_float, "1.5"],
    ["abs2", print_float, "infinity"],
    ["abs3", print_float, "0"],
    ["compare1", print_float_comparison, "FEq"],
    ["compare2", print_float_comparison, "FLt"],
    ["compare3", print_float_comparison, "FGt"],
    ["compare4", print_float_comparison, "FNotComparable"],
    ["compare5", print_float_comparison, "FEq"],
    ["eqb1", print_bool, "true"],
    ["eqb2", print_bool, "false"],
    ["eqb3", print_bool, "false"],
    ["eqb4", print_bool, "true"],
    ["ltb1", print_bool, "true"],
    ["ltb2", print_bool, "false"],
    ["ltb3", print_bool, "false"],
    ["ltb4", print_bool, "false"],
    ["leb1", print_bool, "true"],
    ["leb2", print_bool, "true"],
    ["leb3", print_bool, "false"],
    ["leb4", print_bool, "false"],
    ["classify1", print_float_class, "PNormal"],
    ["classify2", print_float_class, "NNormal"],
    ["classify3", print_float_class, "PZero"],
    ["classify4", print_float_class, "NZero"],
    ["classify5", print_float_class, "PInf"],
    ["classify6", print_float_class, "NInf"],
    ["classify7", print_float_class, "NaN"],
    ["classify8", print_float_class, "PSubn"],
    ["classify9", print_float_class, "NSubn"],
    ["of_uint63_1", print_float, "0"],
    ["of_uint63_2", print_float, "42"],
    ["of_uint63_3", print_float, "9007199254740992"],
    ["of_uint63_4", print_float, "9223372036854776000"],
    ["normfr_mantissa1", print_i63, "4503599627370496"],
    ["normfr_mantissa2", print_i63, "6755399441055744"],
    ["normfr_mantissa3", print_i63, "0"],
    ["normfr_mantissa4", print_i63, "4503599627370496"],
    ["normfr_mantissa5", print_i63, "0"],
    ["frshiftexp1", (val, dataView) => print_prod(val, dataView, print_float, print_i63), "(0.5, 2102)"],
    ["frshiftexp2", (val, dataView) => print_prod(val, dataView, print_float, print_i63), "(0.5, 2101)"],
    ["frshiftexp3", (val, dataView) => print_prod(val, dataView, print_float, print_i63), "(0.75, 2105)"],
    ["frshiftexp4", (val, dataView) => print_prod(val, dataView, print_float, print_i63), "(0, 0)"],
    ["frshiftexp5", (val, dataView) => print_prod(val, dataView, print_float, print_i63), "(infinity, 0)"],
    ["frshiftexp6", (val, dataView) => print_prod(val, dataView, print_float, print_i63), "(nan, 0)"],
    ["ldshiftexp1", print_float, "1"],
    ["ldshiftexp2", print_float, "2"],
    ["ldshiftexp3", print_float, "0.5"],
    ["ldshiftexp4", print_float, "8"],
    ["ldshiftexp5", print_float, "0"],
    ["ldshiftexp6", print_float, "infinity"],
    ["ldshiftexp7", print_float, "infinity"],
    ["next_up1", print_float, "1.0000000000000002"],
    ["next_up2", print_float, "5e-324"],
    ["next_up3", print_float, "5e-324"],
    ["next_up4", print_float, "-1.7976931348623157e+308"],
    ["next_up5", print_float, "infinity"],
    ["next_down1", print_float, "0.9999999999999999"],
    ["next_down2", print_float, "-5e-324"],
    ["next_down3", print_float, "1.7976931348623157e+308"],
    ["next_down4", print_float, "neg_infinity"],
    ["roundtrip1", print_float, "12"],
    ["roundtrip2", print_float, "0.5"],
];

import { readFileSync } from 'fs';

let importObject = { env: {} };

async function run_test([test, pp_fun, expected]) {
    const bytes = readFileSync(`CertiRocq.Tests.float_unit_tests.${test}.wasm`);

    const obj = await WebAssembly.instantiate(
        new Uint8Array (bytes), importObject
    );

    obj.instance.exports.main_function();
    const memory = obj.instance.exports.memory;
    const dataView = new DataView(memory.buffer);
    const res_value = obj.instance.exports.result.value;

    const stdout = process.stdout.write.bind(process.stdout);

    let result = "";

    process.stdout.write = (chunk, encoding, callback) => {
	if (typeof chunk === 'string') {
	    result += chunk;
	}
    };

    pp_fun(res_value, dataView);

    process.stdout.write = stdout;

    return new Promise((resolve, reject) => {
	if (!(result === expected)) {
	    reject(`${test}: expected ${expected}, got ${result}`);
	} else {
	    resolve();
	}
    });

};

Promise.allSettled(tests.map(run_test))
    .then((results) => {
	const errors = results.filter((r) => r.status === "rejected");
	if (errors.length ==0) {
	    console.log("All tests passed!");
	} else {
	    console.log("Some tests failed:");
	    errors.forEach((e) => console.log(e.reason));
	}}).catch();
