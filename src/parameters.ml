
let debug_allowed = ref false
let  enable_debug () = debug_allowed := true
let disable_debug () = debug_allowed := false

let debug_flag = ref false
let debug_start () = debug_flag := true
let debug_stop  () = debug_flag := false
let is_debug_on () = !debug_flag && !debug_allowed

let polymorphism_flag = ref true
let  enable_polymorphism () = polymorphism_flag := true
let disable_polymorphism () = polymorphism_flag := false
let is_polymorphism_on () = !polymorphism_flag

let templ_polymorphism_flag = ref true
let  enable_templ_polymorphism () = templ_polymorphism_flag := true
let disable_templ_polymorphism () = templ_polymorphism_flag := false
let is_templ_polymorphism_on () = !templ_polymorphism_flag

let constraints_flag = ref true
let  enable_constraints () = constraints_flag := true
let disable_constraints () = constraints_flag := false
let is_constraints_on () = !constraints_flag
