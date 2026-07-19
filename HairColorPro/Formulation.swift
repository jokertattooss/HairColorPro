import Foundation

// Mirrors core/formulation.py — chart-based "how to prepare" output.

struct Formulation {
    let primaryTones: String
    let tonerAdditions: String
    let mixingRatio: String
    let applicationGuide: String
    let notes: String
}

enum FormulationEngine {

    static func build(analysis: HairAnalysis, match: PaletteMatch) -> Formulation {
        let best = match.best
        let gray = analysis.grayPercent
        let devVolume = 20, devPercent = 6
        let ratio = "1:1.5"
        let timeMin = gray >= 30 ? 45 : 35

        let chartLine = "Chart shade \(best.code) — \(best.name_fr) / \(best.name_en)  (\(best.hex))"

        let chartMix: String
        if gray >= 50 {
            chartMix = "2/3 tube shade \(best.code) (\(best.name_en)) + 1/3 tube nearest natural base of the same depth — required for \(gray)% gray"
        } else if gray >= 20 {
            chartMix = "3/4 tube shade \(best.code) (\(best.name_en)) + 1/4 tube nearest natural base — for \(gray)% gray"
        } else {
            chartMix = "Full tube shade \(best.code) (\(best.name_en))"
        }

        let toner: String
        switch best.tone {
        case "ash":
            toner = "Cool result: shade is already ash. For extra neutralizing power add 2–3 cm of 38 Intensificateur Bleu (Blue Intensifier)."
        case "copper", "red", "mahogany":
            toner = "Warm/red result: no toner needed. To deepen, add a few cm of 40 Bordeaux; to cool it down, mix in an ash shade (3, 9 or 11) of the same depth."
        case "gold":
            toner = "Golden result: none required. If it turns too brassy, correct with 11 Blond Cendré (Ash Blonde) or 2–3 cm of 38 Intensificateur Bleu."
        default:
            toner = "None required for this natural chart shade."
        }

        let howTo = """
        1) Take the tube of shade \(best.code) — \(best.name_fr) (\(best.name_en)) from the chart.
        2) \(chartMix).
        3) Add developer \(devVolume) vol (\(devPercent)%) at ratio \(ratio) — e.g. 60 g color + 90 g developer.
        4) Mix in a plastic bowl until smooth and creamy (no metal).
        5) Apply on dry, unwashed hair — mid-lengths & ends first if porous, roots last.
        6) Process \(timeMin) min at room temperature, no heat.
        7) Emulsify with warm water, rinse until clear, finish with color-seal (acidic pH) shampoo + conditioner.
        """

        let alts = match.alternatives
            .map { "\($0.code) \($0.name_en)" }
            .joined(separator: "; ")

        let notes = """
        Nearest alternatives on the chart: \(alts).
        Underlying pigment at level \(analysis.level) is \(analysis.underlyingPigment) — lightening exposes it and it must be neutralized with the opposite tone.
        Always perform a skin patch test 48h before and a strand test first.
        """

        return Formulation(
            primaryTones: "\(chartLine)  |  \(chartMix)",
            tonerAdditions: toner,
            mixingRatio: "\(ratio) (color : developer) with \(devVolume) vol (\(devPercent)%) — e.g. 60 g color + 90 g developer",
            applicationGuide: howTo,
            notes: notes
        )
    }
}
