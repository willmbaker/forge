//
// boost_integration.cpp
// Copyright (c) Charles Baker. All rights reserved.
//

#include "stdafx.hpp"
#include <build.hpp>
#include <error/functions.hpp>
#include <assert/assert.hpp>

#ifndef SWEET_EXCEPTIONS_ENABLED

namespace std
{
    class exception;
}

namespace boost
{

/**
// @internal
//
// Override the boost::throw_exception() function that is called instead of 
// throwing exceptions by the Boost Libraries when exceptions are disabled.
//
// @param exception
//  The std::exception that describes the error that has occured.
*/
void boost::throw_exception( const std::exception& exception )
{
    sweet::error::error( exception );
}

}

#endif
