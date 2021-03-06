// Copyright SIX DAY LLC. All rights reserved.

import UIKit

final class StringFormatter {
    /// currencyFormatter of a `StringFormatter` to represent current locale.
    private lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.currencySymbol = ""
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .down
        formatter.numberStyle = .currencyAccounting
        formatter.isLenient = true
        return formatter
    }()
    /// Converts a Double to a `currency String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    ///   - currencyCode: code of the currency.
    /// - Returns: Currency `String` representation.
    func currency(with value: Double, and currencyCode: String) -> String {
        let formatter = currencyFormatter
        formatter.currencyCode = currencyCode
        //Trimming is important because the formatter output for `1.2` becomes "1.2 " (with trailing space) when region = Poland
        return formatter.string(from: NSNumber(value: value))?.trimmed ?? "\(value)"
    }
    /// Converts a Double to a `String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    ///   - precision: symbols after coma.
    /// - Returns: `String` representation.
    func formatter(for double: Double, with precision: Int) -> String {
        return String(format: "%.\(precision)f", double)
    }
    /// Converts a Double to a `String`.
    ///
    /// - Parameters:
    ///   - double: double to convert.
    /// - Returns: `String` representation.
    func formatter(for double: Double) -> String {
        return String(format: "%f", double)
    }
}
