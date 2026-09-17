import SwiftUI

enum ExperimentSection: String, CaseIterable, Identifiable, Sendable {
    case coreMotion
    case haptics
    case sensors
    case shaders
    case simulation

    var id: String { rawValue }

    var track: String {
        switch self {
        case .coreMotion: "A"
        case .haptics: "B"
        case .sensors: "C"
        case .shaders: "D"
        case .simulation: "E"
        }
    }

    var title: String {
        switch self {
        case .coreMotion: "Motion"
        case .haptics: "Haptics"
        case .sensors: "Sensors"
        case .shaders: "Shaders"
        case .simulation: "Simulation"
        }
    }

    var blurb: String {
        switch self {
        case .coreMotion: "Gravity and air"
        case .haptics: "Clicks and strikes"
        case .sensors: "Face, head, voice"
        case .shaders: "Metal and dye"
        case .simulation: "Fluids and cloth"
        }
    }

    var symbol: String {
        switch self {
        case .coreMotion: "gyroscope"
        case .haptics: "waveform.path"
        case .sensors: "face.smiling"
        case .shaders: "circle.hexagongrid"
        case .simulation: "square.stack.3d.up"
        }
    }

    var heading: String { "\(track)  ·  \(title)" }
}

/// One entry in Jimmy’s interaction lab.
struct ExperimentDescriptor: Identifiable {
    let id: String
    let code: String
    let title: String
    let summary: String
    let section: ExperimentSection
    let hardware: String
    let symbol: String
    let coaching: String
    let makeView: () -> AnyView

    init<V: View>(
        id: String,
        code: String,
        title: String,
        summary: String,
        section: ExperimentSection,
        hardware: String,
        symbol: String,
        coaching: String,
        @ViewBuilder content: @escaping () -> V
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.summary = summary
        self.section = section
        self.hardware = hardware
        self.symbol = symbol
        self.coaching = coaching
        self.makeView = { AnyView(content()) }
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return code.lowercased().contains(q)
            || title.lowercased().contains(q)
            || summary.lowercased().contains(q)
            || hardware.lowercased().contains(q)
            || section.title.lowercased().contains(q)
            || section.track.lowercased() == q
    }
}

enum ExperimentCatalog {
    static let hangingChain = ExperimentDescriptor(
        id: "hanging-chain",
        code: "A1",
        title: "Hanging chain",
        summary: "A rope that answers gravity.",
        section: .coreMotion,
        hardware: "CoreMotion  ·  drag on Simulator",
        symbol: "link",
        coaching: "Tilt."
    ) {
        HangingChainView()
    }

    static let pullCord = ExperimentDescriptor(
        id: "pull-cord",
        code: "A2",
        title: "Pull-cord light",
        summary: "Limp fails. A yank toggles the bulb.",
        section: .coreMotion,
        hardware: "Touch velocity  ·  optional tilt",
        symbol: "lightbulb",
        coaching: "Yank."
    ) {
        PullCordView()
    }

    static let compassMercury = ExperimentDescriptor(
        id: "compass-mercury",
        code: "A3",
        title: "Compass mercury",
        summary: "A blob that sits on north.",
        section: .coreMotion,
        hardware: "Magnetometer  ·  location for true north",
        symbol: "location.north.line",
        coaching: "Turn."
    ) {
        CompassMercuryView()
    }

    static let barometricBalloon = ExperimentDescriptor(
        id: "barometric-balloon",
        code: "A4",
        title: "Barometric balloon",
        summary: "Lift. The balloon climbs with the air.",
        section: .coreMotion,
        hardware: "CMAltimeter  ·  drag fallback",
        symbol: "balloon",
        coaching: "Lift."
    ) {
        BarometricBalloonView()
    }

    static let safeDial = ExperimentDescriptor(
        id: "safe-dial",
        code: "B5",
        title: "Safe dial",
        summary: "A click per notch. A clunk at the drop.",
        section: .haptics,
        hardware: "Core Haptics",
        symbol: "lock.rotation",
        coaching: "Turn."
    ) {
        SafeDialView()
    }

    static let zipper = ExperimentDescriptor(
        id: "zipper",
        code: "B6",
        title: "Zipper",
        summary: "Each tooth ticks.",
        section: .haptics,
        hardware: "Core Haptics",
        symbol: "slider.vertical.3",
        coaching: "Pull."
    ) {
        ZipperView()
    }

    static let matchbook = ExperimentDescriptor(
        id: "matchbook",
        code: "B7",
        title: "Matchbook strike",
        summary: "Fast lights. Slow scrapes fail.",
        section: .haptics,
        hardware: "Touch velocity  ·  haptics",
        symbol: "flame",
        coaching: "Strike."
    ) {
        MatchbookView()
    }

    static let waxSeal = ExperimentDescriptor(
        id: "wax-seal",
        code: "B8",
        title: "Wax seal",
        summary: "Hold to melt. Lift to stamp.",
        section: .haptics,
        hardware: "Press duration  ·  haptics",
        symbol: "checkmark.seal",
        coaching: "Hold."
    ) {
        WaxSealView()
    }

    static let faceSpecular = ExperimentDescriptor(
        id: "face-specular",
        code: "C9",
        title: "Face-tracked specular",
        summary: "The highlight follows your eyes.",
        section: .sensors,
        hardware: "TrueDepth / ARKit  ·  tilt fallback",
        symbol: "sparkle",
        coaching: "Look."
    ) {
        FaceSpecularView()
    }

    static let parallaxDiorama = ExperimentDescriptor(
        id: "parallax-diorama",
        code: "C10",
        title: "Parallax diorama",
        summary: "A little room that moves with you.",
        section: .sensors,
        hardware: "TrueDepth / ARKit  ·  tilt fallback",
        symbol: "cube.transparent",
        coaching: "Lean."
    ) {
        ParallaxDioramaView()
    }

    static let chladniPlate = ExperimentDescriptor(
        id: "chladni-plate",
        code: "C11",
        title: "Chladni plate",
        summary: "Sand finds the nodes.",
        section: .sensors,
        hardware: "Microphone  ·  drag-to-tone fallback",
        symbol: "waveform",
        coaching: "Hum."
    ) {
        ChladniPlateView()
    }

    static let metaballMercury = ExperimentDescriptor(
        id: "metaball-mercury",
        code: "D12",
        title: "Metaball mercury",
        summary: "Blobs that merge.",
        section: .shaders,
        hardware: "Metal  ·  touch + tilt",
        symbol: "drop",
        coaching: "Drag."
    ) {
        MetaballMercuryView()
    }

    static let soapFilm = ExperimentDescriptor(
        id: "soap-film",
        code: "D13",
        title: "Soap film",
        summary: "Color from thickness. Then a pop.",
        section: .shaders,
        hardware: "Metal  ·  CoreMotion",
        symbol: "circle.dotted",
        coaching: "Tilt."
    ) {
        SoapFilmView()
    }

    static let inkBleed = ExperimentDescriptor(
        id: "ink-bleed",
        code: "D14",
        title: "Ink bleed",
        summary: "Ink wicks into the grain.",
        section: .shaders,
        hardware: "Touch",
        symbol: "paintbrush.pointed",
        coaching: "Touch."
    ) {
        InkBleedView()
    }

    static let frost = ExperimentDescriptor(
        id: "frost",
        code: "D15",
        title: "Frost",
        summary: "Ice ferns from a fingertip.",
        section: .shaders,
        hardware: "Touch",
        symbol: "snowflake",
        coaching: "Touch."
    ) {
        FrostView()
    }

    static let smokeBox = ExperimentDescriptor(
        id: "smoke-box",
        code: "E16",
        title: "Smoke box",
        summary: "Tilt is gravity. A finger is force.",
        section: .simulation,
        hardware: "CoreMotion  ·  touch",
        symbol: "smoke",
        coaching: "Stir."
    ) {
        SmokeBoxView()
    }

    static let clothPanel = ExperimentDescriptor(
        id: "cloth-panel",
        code: "E17",
        title: "Cloth panel",
        summary: "A sheet you can pull.",
        section: .simulation,
        hardware: "CoreMotion  ·  touch",
        symbol: "square.grid.3x3",
        coaching: "Drag."
    ) {
        ClothPanelView()
    }

    static let ironFilings = ExperimentDescriptor(
        id: "iron-filings",
        code: "E18",
        title: "Iron filings",
        summary: "Your finger is a pole.",
        section: .simulation,
        hardware: "Touch",
        symbol: "location.north",
        coaching: "Hold."
    ) {
        IronFilingsView()
    }

    static let all: [ExperimentDescriptor] = [
        hangingChain,
        pullCord,
        compassMercury,
        barometricBalloon,
        safeDial,
        zipper,
        matchbook,
        waxSeal,
        faceSpecular,
        parallaxDiorama,
        chladniPlate,
        metaballMercury,
        soapFilm,
        inkBleed,
        frost,
        smokeBox,
        clothPanel,
        ironFilings
    ]

    static func experiments(in section: ExperimentSection) -> [ExperimentDescriptor] {
        all.filter { $0.section == section }
    }

    static func experiment(id: String) -> ExperimentDescriptor? {
        let key = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.first { $0.id == key || $0.code.lowercased() == key }
    }

    static func index(of id: String) -> Int? {
        all.firstIndex { $0.id == id }
    }

    static func neighbors(of id: String, in section: ExperimentSection? = nil) -> (prev: ExperimentDescriptor?, next: ExperimentDescriptor?) {
        let list = section.map { experiments(in: $0) } ?? all
        guard let i = list.firstIndex(where: { $0.id == id }), list.count > 1 else {
            return (nil, nil)
        }
        return (
            list[(i + list.count - 1) % list.count],
            list[(i + 1) % list.count]
        )
    }

    static func isForward(from: String, to: String, in section: ExperimentSection) -> Bool {
        let list = experiments(in: section)
        guard let i = list.firstIndex(where: { $0.id == from }),
              let j = list.firstIndex(where: { $0.id == to }) else { return true }
        if i == list.count - 1 && j == 0 { return true }
        if i == 0 && j == list.count - 1 { return false }
        return j > i
    }

    static func resolve(url: URL) -> String? {
        guard url.scheme == "interactions" else { return nil }
        let host = url.host?.lowercased() ?? ""
        let parts = url.pathComponents.filter { $0 != "/" }
        if host == "experiment" || host == "lab" {
            return parts.first.flatMap { experiment(id: $0)?.id }
        }
        if let direct = experiment(id: host) {
            return direct.id
        }
        if let first = parts.first, let match = experiment(id: first) {
            return match.id
        }
        return nil
    }
}
