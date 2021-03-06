// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import Eureka
import BigInt

protocol ConfigureTransactionViewControllerDelegate: class {
    func didEdit(configuration: TransactionConfiguration, in viewController: ConfigureTransactionViewController)
}

class ConfigureTransactionViewController: FormViewController {
    private let configuration: TransactionConfiguration
    private let server: RPCServer
    private let transferType: TransferType
    private let currencyRate: CurrencyRate?
    private let fullFormatter = EtherNumberFormatter.full

    private struct Values {
        static let gasPrice = "gasPrice"
        static let gasLimit = "gasLimit"
        static let nonce = "nonce"
        static let totalFee = "totalFee"
        static let data = "data"
    }

    private var gasPriceRow: SliderTextFieldRow? {
        return form.rowBy(tag: Values.gasPrice) as? SliderTextFieldRow
    }
    private var gasLimitRow: SliderTextFieldRow? {
        return form.rowBy(tag: Values.gasLimit) as? SliderTextFieldRow
    }
    private var nonceRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.nonce) as? TextFloatLabelRow
    }
    private var totalFeeRow: TextRow? {
        return form.rowBy(tag: Values.totalFee) as? TextRow
    }
    private var dataRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.data) as? TextFloatLabelRow
    }

    private var gasLimit: BigInt {
        return BigInt(String(Int(gasLimitRow?.value ?? 0)), radix: 10) ?? BigInt()
    }
    private var gasPrice: BigInt {
        return fullFormatter.number(from: String(Int(gasPriceRow?.value ?? 1)), units: UnitConfiguration.gasPriceUnit) ?? BigInt()
    }
    private var nonceString: String {
        return nonceRow?.value?.trimmed ?? ""
    }
    private var totalFee: BigInt {
        return gasPrice * gasLimit
    }
    private var dataString: String {
        return dataRow?.value ?? "0x"
    }

    private var gasViewModel: GasViewModel {
        return GasViewModel(fee: totalFee, symbol: server.symbol, currencyRate: currencyRate, formatter: fullFormatter)
    }

    lazy var viewModel: ConfigureTransactionViewModel = {
        return ConfigureTransactionViewModel(
            server: server,
            transferType: transferType
        )
    }()

    weak var delegate: ConfigureTransactionViewControllerDelegate?

    init(
        configuration: TransactionConfiguration,
        transferType: TransferType,
        server: RPCServer,
        currencyRate: CurrencyRate?
    ) {
        self.configuration = configuration
        self.transferType = transferType
        self.server = server
        self.currencyRate = currencyRate

        super.init(nibName: nil, bundle: nil)

        navigationItem.title = viewModel.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: R.string.localizable.save(), style: .plain, target: self, action: #selector(save))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let gasPriceGwei = EtherNumberFormatter.full.string(from: configuration.gasPrice, units: UnitConfiguration.gasPriceUnit)

        form = Section()

        +++ Section(
            footer: viewModel.gasPriceFooterText
        )

        <<< SliderTextFieldRow(Values.gasPrice) {
            $0.title = R.string.localizable.configureTransactionGasPriceGweiLabelTitle()
            $0.value = Float(gasPriceGwei) ?? 1
            $0.minimumValue = Float(GasPriceConfiguration.minPrice / BigInt(UnitConfiguration.gasPriceUnit.rawValue))
            $0.maximumValue = Float(GasPriceConfiguration.maxPrice / BigInt(UnitConfiguration.gasPriceUnit.rawValue))
            $0.steps = UInt((GasPriceConfiguration.maxPrice / GasPriceConfiguration.minPrice))
            $0.displayValueFor = { (rowValue: Float?) in
                return "\(Int(rowValue ?? 1))"
            }
            $0.onChange { [unowned self] _ in
                self.recalculateTotalFee()
            }
        }

        +++ Section(
            footer: viewModel.gasLimitFooterText
        )

        <<< SliderTextFieldRow(Values.gasLimit) {
            $0.title = R.string.localizable.configureTransactionGasLimitLabelTitle()
            $0.value = Float(configuration.gasLimit.description) ?? Float(GasLimitConfiguration.minGasLimit)
            $0.minimumValue = Float(GasLimitConfiguration.minGasLimit)
            $0.maximumValue = Float(GasLimitConfiguration.maxGasLimit)
            $0.steps = UInt((GasLimitConfiguration.maxGasLimit - GasLimitConfiguration.minGasLimit) / 1000)
            $0.displayValueFor = { (rowValue: Float?) in
                return "\(Int(rowValue ?? 1))"
            }
            $0.onChange { [unowned self] _ in
                self.recalculateTotalFee()
            }
        }

        +++ Section()

        <<< AppFormAppearance.textFieldFloat(tag: Values.nonce) { [weak self] in
            guard let strongSelf = self else { return }
            $0.title = R.string.localizable.configureTransactionNonceLabelTitle()
            $0.value = strongSelf.configuration.nonce.flatMap { String($0) }
        }.cellUpdate { cell, row in
            cell.textField.keyboardType = .numberPad
        }

        +++ Section {
            $0.hidden = Eureka.Condition.function([], { [weak self] _ in
                guard let strongSelf = self else { return true }
                return strongSelf.viewModel.isDataInputHidden
            })
        }
        <<< AppFormAppearance.textFieldFloat(tag: Values.data) { [weak self] in
            guard let strongSelf = self else { return }
            $0.title = R.string.localizable.configureTransactionDataLabelTitle()
            $0.value = strongSelf.configuration.data.hexEncoded
        }

        +++ Section()

        <<< TextRow(Values.totalFee) {
            $0.title = R.string.localizable.configureTransactionTotalNetworkFeeLabelTitle()
            $0.disabled = true
        }

        recalculateTotalFee()
    }

    func recalculateTotalFee() {
        let feeAndSymbol = gasViewModel.feeText
        totalFeeRow?.value = feeAndSymbol
        totalFeeRow?.updateCell()
    }

    @objc func save() {
        guard gasLimit <= ConfigureTransaction.gasLimitMax else {
            return displayError(error: ConfigureTransactionError.gasLimitTooHigh)
        }

        guard totalFee <= ConfigureTransaction.gasFeeMax else {
            return displayError(error: ConfigureTransactionError.gasFeeTooHigh)
        }

        if !nonceString.isEmpty {
            guard let nonce = Int(nonceString), nonce >= 0 else {
                return displayError(error: ConfigureTransactionError.nonceNotPositiveNumber)
            }
        }

        let data: Data = {
            if dataString.isEmpty {
                return Data()
            }
            return Data(hex: dataString.drop0x)
        }()

        let nonce: Int? = Int(nonceString)

        let hasUserAdjustedGasPrice = self.configuration.hasUserAdjustedGasPrice || (self.configuration.gasPrice != gasPrice)
        let hasUserAdjustedGasLimit = self.configuration.hasUserAdjustedGasLimit || (self.configuration.gasLimit != gasLimit)
        let configuration = TransactionConfiguration(
            gasPrice: gasPrice,
            gasLimit: gasLimit,
            data: data,
            nonce: nonce,
            hasUserAdjustedGasPrice: hasUserAdjustedGasPrice,
            hasUserAdjustedGasLimit: hasUserAdjustedGasLimit
        )
        delegate?.didEdit(configuration: configuration, in: self)
    }
}
