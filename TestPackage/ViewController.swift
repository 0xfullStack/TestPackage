//
//  ViewController.swift
//  TestPackage
//
//  Created by linshizai on 2022/6/12.
//

import UIKit
import CryptoCompare
import RxSwift
import Cryptoless
import Signer

class ViewController: UIViewController {

    @IBOutlet weak var price: UILabel!
    
    @IBOutlet weak var price1: UILabel!
    
    @IBOutlet weak var testTransaction: UIButton!
    let cryptoless = Cryptoless(
        web3Token:"eyJib2R5IjoiV2ViMyBUb2tlbiBWZXJzaW9uOiAyXG5Ob25jZTogMzE1MDA4MDFcbklzc3VlZCBBdDogTW9uLCAzMCBNYXkgMjAyMiAxMTo1Njo1MCBHTVRcbkV4cGlyYXRpb24gVGltZTogVHVlLCAzMCBNYXkgMjAyMyAxMTo1Njo1MCBHTVQiLCJzaWduYXR1cmUiOiIweDAwMzEwYTViZTRkYTYxZjM2Njc5YmJmNDM1ZjVmODYyNjAxNjQzMTJjNGQyMTEyOTY1ZGZkNjM3MjNmNDE0ODI0ZTMxZmI1NGM1OGViZjkyYjhiMTQyZDhhNDM1NWI2MDcxODljNzZhMDRlMThmN2QyZDhjNzhhMzIzZmI5YmJkMWIifQ=="
    )
    private let bag = DisposeBag()
    override func viewDidLoad() {
        super.viewDidLoad()

        testCryptoless()
//        testCryptoCompare()
        
        testTransaction.rx.tap.subscribe(onNext: { [weak self] _ in
            self?.testTx()
        })
        .disposed(by: bag)
    }
    
    public func testRegister() async throws {
        let signer: Signer = HDWallet()
        let ownerKeyPair = signer.deriveOwnerKeyPair()
        let ownerPublicKey = ownerKeyPair.public
        
//        while registration?.status != "registered" {
//            registration = try await cls!.register(ownerPublicKey: ownerPublicKey.toHexString())
//            if registration?.status != "registered" { sleep(2) } // matic block time
//        }
        
        register(ownerPublicKey: ownerPublicKey.toHexString())
    }
    
    private var registerBag = DisposeBag()
    private func register(ownerPublicKey: String) {
        registerBag = DisposeBag()
        Cryptoless
            .register(ownerPublicKey: ownerPublicKey)
            .subscribe { [weak self] registration in
                guard let self = self else { return }
                if registration.status != "registered" {
                    sleep(2)
                    self.register(ownerPublicKey: ownerPublicKey)
                }
            } onError: { [weak self] error in
                guard let self = self else { return }
                sleep(2)
                self.register(ownerPublicKey: ownerPublicKey)
            }
            .disposed(by: registerBag)
    }
    
    public func testFetchginAccounts() -> Observable<[Cryptoless.Account]> {
        let signer: Signer = HDWallet()
        let networks = [Cryptoless.Network]()
        
        let publicKeys = networks.map { signer.deriveKeyPair(path: $0.derivationPath, index: .zero).public.toHexString() }
        return cryptoless
            .fetchAccounts(publicKeys: publicKeys)
            .flatMapLatest { [weak self] fetchedAccounts -> Observable<[Cryptoless.Account]> in
                guard let self = self else { return .never() }

                let result: [Observable<Cryptoless.Account>] = networks.compactMap({ network in
                    guard fetchedAccounts.filter({ $0.networkCode == network.code }).isEmpty else {
                        return nil
                    }
                    let publicKey = signer.deriveKeyPair(path: network.derivationPath, index: .zero).public.toHexString()
                    let deployAccount = self.cryptoless.deployAccount(networkCode: network.code, publicKeys: [publicKey], threshold: 1)
                    return deployAccount
                })
                return Observable
                    .concat(result)
                    .toArray()
                    .map({ $0 + fetchedAccounts })
                    .asObservable()
            }
    }
    
    private func testTx() {
        let networkId = "eth"
        let coinId = "eth"
        
        let testSeedPhrase = "protect notable remember dress swamp wife train thrive blur spirit claw charge arch enhance crumble"
        let wallet = try! HDWallet(testSeedPhrase)
        let key = wallet.deriveKeyPair(path: "m/44'/60'/0'/0/")
        
        cryptoless
            .transfer(
                symbol: coinId,
                networkCode: networkId,
                from: "0xADB6e54257207d6B5df204Aa4038C4B64B9586f1",
                to: "0xADB6e54257207d6B5df204Aa4038C4B64B9586f1",
                amount: "0.001"
            )
            .flatMapLatest({ [weak self] transfer -> Observable<Cryptoless.Transaction> in
                guard let self = self else { return .never() }
                print("=================================================================")
                print("1. Make Transfer: \(transfer)")
                print("=================================================================")
                
                let tx = transfer._embedded!.transactions.first!
                let signing = tx.requiredSignings!.first!
                let sig = try! key.sign([UInt8](hex: signing.hash))
                let signatures = Cryptoless.Transaction.Signature(
                    hash: signing.hash,
                    publicKey: signing.publicKeys.first!,
                    signature: sig.toHexString()
                )
                return self.cryptoless.signTransaction(id: tx.id, signatures: [signatures])
            })
            .flatMapLatest({ [weak self] transaction -> Observable<Cryptoless.Transaction> in
                guard let self = self else { return .never() }
                print("=================================================================")
                print("2. SignTransaction: \(transaction)")
                print("=================================================================")
                return self.cryptoless.sendTransaction(id: transaction.id)
            })
            .subscribe(onNext: { transaction in
                print("=================================================================")
                print("3. SendTransaction: \(transaction)")
                print("=================================================================")
            })
            .disposed(by: bag)
    }
    
    private func testCryptoless() {
        cryptoless
            .subscribe(.holder)
            .mapObject([Cryptoless.Holder].self)
            .subscribe(onNext: { [weak self] holders in
                print(holders)
                print("=================================================================")
                print("Holders: \(holders)")
                self?.price.text = "holders count: \(holders.filter({ $0.symbol == "ETH" }).first?.updatedTime)"
                print("=================================================================")
            })
            .disposed(by: bag)
        
        cryptoless
            .subscribe(.instruction)
            .mapObject([Cryptoless.Instruction].self)
            .subscribe(onNext: { [weak self] instructions in
                print("=================================================================")
                print("Instructions: \(instructions)")
                self?.price1.text = "Instructions count: \(instructions.count)"
                print("=================================================================")
            })
            .disposed(by: bag)
    }

    private func testCryptoCompare() {
        let syms: [(String, String)] = [
            (fsym: "BTC", tsym: "USD")
        ]

        CryptoCompare
            .shared
            .subscribe(.market(syms: syms))
            .subscribe { [weak self] data in
                if let market = try? JSONDecoder().decode(CryptoCompare.Market.self, from: data) {
                    
                    self?.price.text = "\(market.price)"
                    print(market)
                }
            } onError: { [weak self] error in
                self?.price.text = error.localizedDescription
//                print(error.localizedDescription)
            }
            .disposed(by: bag)
    }
}

