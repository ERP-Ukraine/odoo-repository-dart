# odoo_repository changelog

## 0.4.3

Truncate generated id to 32 bit integer

## 0.4.2

Add support for vals and vals_list in create

## 0.4.1

Fix issue with encoding datetime of a RPC call

## 0.4.0

Introduce OdooId class that is used to find what ids needs to be updated during sync.

## 0.3.1

Call create() and write() with toVals()

## 0.3.0

Pass OdooEnvironment to OdooRepository as cyclic reference

## 0.2.0

Added OdooEnvironment to coordinate call queue of all repositories

## 0.1.5

Implemented create and write methods using write-through cache approach.

## 0.1.4

Upgrade equatable dependency to 2.0.3

## 0.1.3

Improved documentation with examples

## 0.1.2

Added RPC calls throttling

## 0.1.1

Offline mode example

## 0.1.0

Initial release
