# ICRC-1 Implementation
This repo contains the implementation of the 
[ICRC-1](https://github.com/dfinity/ICRC-1) token standard. 

## References and other implementations
- [demergent-labs/ICRC-1 (Typescript)](https://github.com/demergent-labs/ICRC-1)
- [Ledger ref in Motoko](https://github.com/dfinity/ledger-ref/blob/main/src/Ledger.mo)
- [ICRC1 Rosetta API](https://github.com/dfinity/ic/blob/master/rs/rosetta-api/icrc1/ledger)

## Documentation 
- [markdown](./docs/index.md)
- [web](https://natlabs.github.io/icrc1/)
 
## Getting Started 
- Expose the ICRC-1 token functions from your canister 
  - Import the `icrc1` lib and expose them in an `actor` class.
  
    Take a look at the [examples](./example/icrc1/main.mo)
    
- Launch the basic token with all the standard functions for ICRC-1
  ```motoko
    git clone https://github.com/NatLabs/icrc1`
    cd icrc1
    dfx start --background

    dfx deploy --argument '( record {\
        name = "<Insert Token Name>", \
        symbol = "<Insert Symbol>", \
        decimals = <Insert Decimal>, \
        fee = <Insert Fee> , \
        max_supply = <Insert Max Supply>, \
        minting_account = opt record { \
            owner = principal "<Insert Principal>"; \
            subaccount = <?(Insert subaccount bytes) | null> \
        }, \
        initial_balances = vec {} \
    })'
  ```

- Create a token dynamically from a canister
    ```motoko
        import Nat8 "mo:base/Nat8";
        import Token "mo:icrc1/Canisters/Token";

        actor{
            let decimals = 8; // replace with your chosen number of decimals

            func add_decimals(n: Nat): Nat{
                n * 10 ** decimals
            };

            let token_canister = Token.Token({
                name = "<Insert Token Name>";
                symbol = "<Insert Token Symbol>";
                decimals = Nat8.fromNat(decimals);
                fee = add_decimals(<Insert Fee>);
                max_supply = add_decimals(<Insert Max Supply>);
                minting_account = ?{
                    owner = Principal.fromText("<Insert Principal>");
                    subaccount = null
                };
                transaction_window = null;
                initial_balances = [];
            });
        }
    ```

## Tests
- Download and Install [vessel](https://github.com/dfinity/vessel)
- Run `make test`
