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
// Interactive CLI example usage:
// If you run this file with Node, it will prompt for values. Press Enter to accept a default.
const readline = require('readline');

function askQuestion(rl, question) {
    return new Promise(resolve => rl.question(question, answer => resolve(answer)));
}

async function runInteractive() {
    const defaults = {
        initialCapital: 7400,
        monthlyContribution: 2300,
        annualRate: 15,
        years: 20,
        compoundingFrequency: 12,
    };

    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

    try {
        const initialCapitalInput = await askQuestion(rl, `Initial capital (default ${defaults.initialCapital}): `);
        const monthlyContributionInput = await askQuestion(rl, `Monthly contribution (default ${defaults.monthlyContribution}): `);
        const annualRateInput = await askQuestion(rl, `Annual interest rate in % (default ${defaults.annualRate}): `);
        const yearsInput = await askQuestion(rl, `Time in years (default ${defaults.years}): `);
        const compoundingFrequencyInput = await askQuestion(rl, `Compounding frequency per year (default ${defaults.compoundingFrequency}): `);

        const initialCapital = initialCapitalInput.trim() === '' ? defaults.initialCapital : parseFloat(initialCapitalInput);
        const monthlyContribution = monthlyContributionInput.trim() === '' ? defaults.monthlyContribution : parseFloat(monthlyContributionInput);
        const annualRate = annualRateInput.trim() === '' ? defaults.annualRate : parseFloat(annualRateInput);
        const years = yearsInput.trim() === '' ? defaults.years : parseInt(yearsInput, 10);
        const compoundingFrequency = compoundingFrequencyInput.trim() === '' ? defaults.compoundingFrequency : parseInt(compoundingFrequencyInput, 10);

        const invalids = [];
        if (!Number.isFinite(initialCapital)) invalids.push('Initial capital');
        if (!Number.isFinite(monthlyContribution)) invalids.push('Monthly contribution');
        if (!Number.isFinite(annualRate)) invalids.push('Annual interest rate');
        if (!Number.isInteger(years) || years <= 0) invalids.push('Time in years');
        if (!Number.isInteger(compoundingFrequency) || compoundingFrequency <= 0) invalids.push('Compounding frequency');

        if (invalids.length > 0) {
            console.error('Invalid input for:', invalids.join(', '));
            rl.close();
            process.exit(1);
        }

        const details = investmentDetailByYear(initialCapital, monthlyContribution, annualRate, years, compoundingFrequency);
        console.log('\nYear-by-year breakdown:');
        details.forEach(entry => {
            const formatted = entry.balance.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
            console.log(`Year ${entry.year}: $${formatted}`);
        });
    } finally {
        rl.close();
    }
}

// Run interactively if this file is executed directly.
if (require.main === module) {
    runInteractive().catch(err => {
        console.error('Error:', err);
        process.exit(1);
    });
}

// Export the function so it can be required/imported by other modules.
module.exports = { investmentDetailByYear };
