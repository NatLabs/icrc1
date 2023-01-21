# ICRC-1 Implementation
This repo contains the implementation of the 
[ICRC-1](https://github.com/dfinity/ICRC-1) token standard. 

## References and other implementations
- [demergent-labs/ICRC-1 (Typescript)](https://github.com/demergent-labs/ICRC-1)
- [Ledger ref in Motoko](https://github.com/dfinity/ledger-ref/blob/main/src/Ledger.mo)
- [ICRC1 Rosetta API](https://github.com/dfinity/ic/blob/master/rs/rosetta-api/icrc1/ledger)

## Documentation 
- [markdown](https://github.com/NatLabs/icrc1/blob/main/docs/ICRC1/lib.md#function-init)
- [web](https://natlabs.github.io/icrc1/ICRC1/lib.html#init)
 
## Getting Started 
- Expose the ICRC-1 token functions from your canister 
  - Import the `icrc1` lib and expose them in an `actor` class.
  
    Take a look at the [examples](./example/icrc1/main.mo)
    
- Launch the basic token with all the standard functions for ICRC-1
  - Install the [mops](https://j4mwm-bqaaa-aaaam-qajbq-cai.ic0.app/#/docs/install) package manager
  - Replace the values enclosed in `< >` with your desired values and run in the terminal 

  ```motoko
    git clone https://github.com/NatLabs/icrc1
    cd icrc1
    mops install
    dfx start --background --clean

    dfx deploy icrc1 --argument '( record {                     
        name = "<Insert Token Name>";                         
        symbol = "<Insert Symbol>";                           
        decimals = 6;                                           
        fee = 1_000_000;                                        
        max_supply = 1_000_000_000_000;                         
        initial_balances = vec {                                
            record {                                            
                record {                                        
                    owner = principal "<Insert Principal>";   
                    subaccount = null;                          
                };                                              
                100_000_000                                 
            }                                                   
        };                                                      
        min_burn_amount = 10_000;                         
        minting_account = null;                                 
        advanced_settings = null;                               
    })'
  ```

- Create a token dynamically from a canister
    ```motoko
        import Nat8 "mo:base/Nat8";
        import Token "mo:icrc1/ICRC1/Canisters/Token";

        actor{
            let decimals = 8; // replace with your chosen number of decimals

            func add_decimals(n: Nat): Nat{
                n * 10 ** decimals
            };

            let pre_mint_account = {
                owner = Principal.fromText("<Insert Principal>");
                subaccount = null;
            };

            let token_canister = Token.Token({
                name = "<Insert Token Name>";
                symbol = "<Insert Token Symbol>";
                decimals = Nat8.fromNat(decimals);
                fee = add_decimals(1);
                max_supply = add_decimals(1_000_000);

                // pre-mint 100,000 tokens for the account
                initial_balances = [(pre_mint_account, add_decimals(100_000))]; 

                min_burn_amount = add_decimals(10);
                minting_account = null; // defaults to the canister id of the caller
                advanced_settings = null; 
            });
        }
    ```

> The fields for the `advanced_settings` record are documented [here](./docs/ICRC1/Types.md#type-advancedsettings)

## Textual Representation of the ICRC-1 Accounts
This library implements the [Textual Representation](https://github.com/dfinity/ICRC-1/blob/main/standards/ICRC-1/README.md#textual-representation-of-accounts) format for accounts defined by the standard. It utilizes this implementation to encode each account into a sequence of bytes for improved hashing and comparison.
To help with this process, the library provides functions in the [ICRC1/Account](./src/ICRC1/Account.mo) module for [encoding](./docs/ICRC1/Account.md#encode), [decoding](./docs/ICRC1/Account.md#decode), [converting from text](./docs/ICRC1/Account.md#fromText), and [converting to text](./docs/ICRC1/Account.md#toText).


## Tests
#### Internal Tests
- Download and Install [vessel](https://github.com/dfinity/vessel)
- Run `make test` 
- Run `make actor-test`

#### [Dfinity's ICRC-1 Reference Tests](https://github.com/dfinity/ICRC-1/tree/main/test)
- Install Rust and Cargo via [rustup](https://rustup.rs/)

```
    curl https://sh.rustup.rs -sSf | sh
```

- Follow these [instructions](./readme.md#L29-40) to start the dfx local replica and deploy the icrc1 token
- Once the canister is deployed you should see a message like this

```
    ...
    Building canisters...
    Shrink WASM module size.
    Installing canisters...
    Installing code for canister icrc1, 
    with canister ID q3fc5-haaaa-aaaaa-aaahq-cai
```
- Copy the text on the last line after the `ID` and replace it with the `<Enter Canister ID>` in the command below

```
    make ref-test ID=<Enter Canister ID>
```

## Funding

This library was initially incentivized by [ICDevs](https://icdevs.org/). You can view more about the bounty on the [forum](https://forum.dfinity.org/t/completed-icdevs-org-bounty-26-icrc-1-motoko-up-to-10k/14868/54) or [website](https://icdevs.org/bounties/2022/08/14/ICRC-1-Motoko.html). The bounty was funded by The ICDevs.org community and the DFINITY Foundation and the award was paid to [@NatLabs](https://github.com/NatLabs). If you use this library and gain value from it, please consider a [donation](https://icdevs.org/donations.html) to ICDevs.