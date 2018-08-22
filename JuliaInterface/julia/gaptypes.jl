#############################################################################
##
##  JuliaInterface package
##
##  Copyright 2017
##    Thomas Breuer, RWTH Aachen University
##    Sebastian Gutsche, Siegen University
##
#############################################################################

module GAPUtils

"""
    get_function_symbols_in_module(module_t::Module) :: Array{Symbol,1}

> Returns all function symbols in the module `module_t`.
"""
function get_function_symbols_in_module(module_t)
    module_name = string(Main.module_name(module_t))
    string_list = Base.REPLCompletions.completions( module_name * ".", length( module_name ) + 1 )[1]
    list = [ Symbol(x) for x in string_list ]
    list = filter(i->isdefined(module_t,i) && isa(eval((:($module_t.$i))),Function),list)
    return list
end

"""
    get_variable_symbols_in_module(module_t::Module) :: Array{Symbol,1}

> Returns all variable symbols in the module `module_t`, i.e.,
> all symbols that do not point to functions.
"""
function get_variable_symbols_in_module(module_t)
    module_name = string(Main.module_name(module_t))
    string_list = Base.REPLCompletions.completions( module_name * ".", length( module_name ) + 1 )[1]
    list = [ Symbol(x) for x in string_list ]
    list = filter(i->isdefined(module_t,i) && ! isa(eval((:($module_t.$i))),Function),list)
    return list
end

"""
    call_with_catch( juliafunc, arguments )

> Returns a tuple `( ok, val )`
> where `ok` is either `true`, meaning that calling the function `juliafunc`
> with `arguments` returns the value `val`,
> or `false`, meaning that the function call runs into an error;
> in the latter case, `val` is set to the string of the error message.
"""
function call_with_catch( juliafunc, arguments )
    try
      res = Core._apply( juliafunc, arguments )
      return ( true, res )
    catch e
      return ( false, string( e ) )
    end
end

export get_function_symbols_in_module, get_variable_symbols_in_module,
       call_with_catch

end

##########################################################################

module GAP

#import Base: +

export gap_funcs, prepare_func_for_gap, GapObj, GapFunc, gap_object_finalizer

gap_funcs = Array{Any,1}();

## currently unused
gap_object_finalizer = function(obj)
    ccall(Main.gap_unpin_gap_obj,Cvoid,(Cint,),obj.index)
end

"""
    GapObj

> Holds a pointer to an object in the GAP CAS, and additionally some internal information for
> GAP's garbage collection. It can be used as arguments for GapFunc's.
"""
mutable struct GapObj
    ptr::Ptr{Cvoid}
    index
    function GapObj(ptr::Ptr{Cvoid})
        index = ccall(Main.gap_pin_gap_obj,Cint,(Ptr{Cvoid},),ptr)
        new_obj = new(ptr,index)
        finalizer(gap_object_finalizer,new_obj)
        return new_obj
    end
end

"""
    GapFunc

> Holds a pointer to a function in the GAP CAS.
> Such functions can be called on GapObj's.
"""
struct GapFunc
    ptr::Ptr{Cvoid}
end

"""
    (func::GapFunc)(args...)

> This function makes it possible to call GapFunc objects on
> GapObj objects. It also makes sure that the resulting object
> is a GapObj holding a pointer to the result.
> There is no argument number checking here, all checks on the arguments
> (except that they are GapObj) is done by GAP itself.
"""
function(func::GapFunc)(args...)
    arg_array = collect(args)
    arg_array = map(i->i.ptr,arg_array)
    length_array = length(arg_array)
    gap_arg_list = GapObj(ccall(Main.gap_MakeGapArgList,Ptr{Cvoid},
                                (Cint,Ptr{Ptr{Cvoid}}),length_array,arg_array))
    return GapObj(ccall(Main.gap_CallFuncList,Ptr{Cvoid},
                        (Ptr{Cvoid},Ptr{Cvoid}),func.ptr,gap_arg_list.ptr))
end

## Internal function, not to be used.
## This function prepares a function that manipulates
## GAP pointers directly (for example by using GapFunc objects)
## to be included as a kernel function into GAP. It has no real
## purpose to be called from Julia directly.
function prepare_func_for_gap(gap_func)
    return_func = function(self,args...)
        new_args = map(GapObj,args)
        return_value = gap_func(new_args...)
        return return_value.ptr
    end
    push!(gap_funcs,return_func)
    return return_func
end

end

baremodule GAPFuncs
end
