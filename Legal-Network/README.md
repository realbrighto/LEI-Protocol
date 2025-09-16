# Legal Entity Registry - Blockchain-based LEI Management System

A comprehensive smart contract for managing Legal Entity Identifiers (LEI) on the blockchain, providing immutable registration, ownership tracking, lifecycle management, and regulatory compliance features for financial institutions and regulatory bodies.

## Overview

The Legal Entity Registry smart contract enables decentralized management of Legal Entity Identifiers with the following core capabilities:

- Immutable LEI registration and record-keeping
- Ownership tracking and transfer functionality
- Lifecycle status management (Active, Suspended, Expired, Retired)
- Administrative privilege management with role-based access control
- Portfolio management for entity owners
- Batch processing capabilities for regulatory compliance

## Features

### Core Functionality
- **LEI Registration**: Register new Legal Entity Identifiers with designated owners and expiration dates
- **Ownership Management**: Transfer entity ownership between principals with proper validation
- **Lifecycle Management**: Update entity status and extend expiration dates
- **Portfolio Tracking**: Maintain owner portfolios with up to 50 entities per owner
- **Administrative Controls**: Multi-level administrative access (Basic and Super Admin)

### Security Features
- Role-based access control with administrative privileges
- Input validation for all critical parameters
- Comprehensive error handling with descriptive error codes
- Event logging for audit trails and regulatory compliance

## Contract Structure

### Data Structures

#### Legal Entity Records
```clarity
{
  entity-owner: principal,
  lifecycle-status: (string-ascii 12),
  registration-block: uint,
  expiration-block: uint,
  last-modification-block: uint
}
```

#### Owner Portfolios
```clarity
{
  total-entity-count: uint,
  owned-entity-identifiers: (list 50 (string-ascii 20))
}
```

#### Administrative Roles
```clarity
{
  access-granted: bool,
  administrative-level: (string-ascii 10)
}
```

## Error Codes

### Access Control Errors
- **ERR-UNAUTHORIZED-ACCESS (100)**: Insufficient permissions for the requested operation
- **ERR-INSUFFICIENT-PERMISSIONS (101)**: User lacks required permissions
- **ERR-ADMIN-PRIVILEGES-REQUIRED (102)**: Administrative privileges required
- **ERR-INVALID-ADMINISTRATOR (103)**: Invalid administrator configuration

### Input Validation Errors
- **ERR-MALFORMED-LEI-FORMAT (200)**: LEI format does not meet requirements
- **ERR-INVALID-LIFECYCLE-STATUS (201)**: Invalid lifecycle status provided
- **ERR-INVALID-EXPIRATION-DATE (202)**: Invalid or past expiration date
- **ERR-INVALID-PRINCIPAL-ADDRESS (203)**: Invalid principal address format

### Business Logic Errors
- **ERR-DUPLICATE-LEI-EXISTS (300)**: LEI already exists in registry
- **ERR-LEI-RECORD-NOT-FOUND (301)**: LEI record not found
- **ERR-LEI-HAS-EXPIRED (302)**: LEI has expired
- **ERR-IDENTICAL-OWNER-TRANSFER (303)**: Cannot transfer to same owner

## Public Functions

### Administrative Functions

#### `transfer-contract-ownership`
Transfers contract ownership to a new administrator.
```clarity
(transfer-contract-ownership (new-contract-owner principal))
```

#### `grant-administrative-privileges`
Grants administrative privileges to a specified address.
```clarity
(grant-administrative-privileges (new-admin-address principal) (admin-level (string-ascii 10)))
```

#### `revoke-administrative-privileges`
Revokes administrative privileges from a specified address.
```clarity
(revoke-administrative-privileges (target-admin-address principal))
```

### Entity Management Functions

#### `register-legal-entity-identifier`
Registers a new Legal Entity Identifier with ownership and expiration.
```clarity
(register-legal-entity-identifier 
  (entity-id (string-ascii 20)) 
  (designated-owner principal) 
  (expiration-block-height uint))
```

#### `transfer-entity-ownership`
Transfers entity ownership between principals.
```clarity
(transfer-entity-ownership (entity-id (string-ascii 20)) (new-entity-owner principal))
```

#### `update-entity-lifecycle-status`
Updates the lifecycle status of an entity.
```clarity
(update-entity-lifecycle-status (entity-id (string-ascii 20)) (new-status (string-ascii 12)))
```

#### `extend-entity-expiration`
Extends the expiration date of an entity.
```clarity
(extend-entity-expiration (entity-id (string-ascii 20)) (new-expiration-block uint))
```

#### `batch-process-expired-entities`
Processes multiple expired entities (Super Admin only).
```clarity
(batch-process-expired-entities (entity-list (list 20 (string-ascii 20))))
```

## Read-Only Functions

### Query Functions

#### `get-entity-record-details`
Retrieves complete entity record details.
```clarity
(get-entity-record-details (entity-id (string-ascii 20)))
```

#### `check-entity-validity`
Checks if an entity is currently active and valid.
```clarity
(check-entity-validity (entity-id (string-ascii 20)))
```

#### `get-owner-portfolio-details`
Retrieves an owner's complete portfolio information.
```clarity
(get-owner-portfolio-details (portfolio-owner principal))
```

#### `get-contract-operational-statistics`
Retrieves contract operational statistics.
```clarity
(get-contract-operational-statistics)
```

#### `get-administrative-information`
Retrieves administrative information for an address.
```clarity
(get-administrative-information (target-address principal))
```

## Usage Examples

### Registering a New LEI
```clarity
;; Register a new LEI with 1000 block expiration
(contract-call? .legal-entity-registry register-legal-entity-identifier 
  "ABCDEFGHIJKLMNOPQRST" 
  'SP1EXAMPLE123456789 
  (+ block-height u1000))
```

### Transferring Entity Ownership
```clarity
;; Transfer entity to new owner
(contract-call? .legal-entity-registry transfer-entity-ownership 
  "ABCDEFGHIJKLMNOPQRST" 
  'SP2NEWOWNER987654321)
```

### Checking Entity Status
```clarity
;; Check if entity is valid and active
(contract-call? .legal-entity-registry check-entity-validity 
  "ABCDEFGHIJKLMNOPQRST")
```

## Deployment and Initialization

Upon deployment, the contract automatically:
1. Sets the deployer as the contract administrator
2. Grants the deployer super administrative privileges
3. Initializes the total entity registration counter to zero

## Administrative Levels

### Super Admin
- Can process expired entities in batches
- Has all basic admin privileges
- Designated by "SUPER" administrative level

### Basic Admin
- Can register new LEIs
- Can update entity lifecycle status
- Can extend entity expiration dates
- Designated by "BASIC" administrative level

## Compliance and Regulatory Features

### Event Logging
The contract emits events for all major operations:
- Entity registration events
- Ownership transfer events
- Lifecycle status updates
- Expiration extensions

### Audit Trail
All modifications are tracked with block heights for comprehensive audit capabilities.

### Data Integrity
- LEI format validation ensures 20-character ASCII compliance
- Principal address validation prevents invalid ownership assignments
- Expiration date validation prevents backdated registrations