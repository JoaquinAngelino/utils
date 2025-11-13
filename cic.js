/**
 * Year-by-year investment breakdown with compound interest and monthly contributions.
 *
 * @param {number} initialCapital - Initial capital amount.
 * @param {number} monthlyContribution - Monthly contribution amount.
 * @param {number} annualRate - Annual interest rate (percentage).
 * @param {number} years - Time in years.
 * @param {number} compoundingFrequency - Number of times interest is compounded per year (12 for monthly).
 * @returns {Array} - Array of objects { year, balance } representing each year and the balance.
 */
function investmentDetailByYear(initialCapital, monthlyContribution, annualRate, years, compoundingFrequency) {
    const rateDecimal = annualRate / 100;
    const periodRate = rateDecimal / compoundingFrequency;
    let balance = initialCapital;
    const result = [{ year: 0, balance: balance }];

    for (let year = 1; year <= years; year++) {
        for (let period = 1; period <= compoundingFrequency; period++) {
            balance = balance * (1 + periodRate) + monthlyContribution;
        }
        result.push({ year, balance: parseFloat(balance.toFixed(2)) });
    }
    return result;
}

// Example usage:
const details = investmentDetailByYear(
    7400, // Initial capital
    2300, // Monthly contribution
    15, // Annual interest rate
    20, // Time in years
    12, // Compounding frequency per year (12 months)
);
details.forEach(entry => {
    // Print the yearly breakdown with the amount formatted for English (US) locale
    entry.balance = entry.balance.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    console.log(`Year ${entry.year}: $${entry.balance}`);
});
