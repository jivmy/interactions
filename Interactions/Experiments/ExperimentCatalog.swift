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
        case .coreMotion: "Gravity, compass, air pressure"
        case .haptics: "Clicks, ticks, strikes"
        case .sensors: "Face, head, microphone"
        case .shaders: "Metal and diffusion"
        case .simulation: "Fluids, cloth, fields"
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
        summary: "Verlet rope pinned at the top, swung by real device gravity.",
        section: .coreMotion,
        hardware: "CoreMotion  ·  drag on Simulator",
        symbol: "link",
        coaching: "Tilt or flick the phone. Drag a link if you’re on Simulator."
    ) {
        HangingChainView()
    }

    static let pullCord = ExperimentDescriptor(
        id: "pull-cord",
        code: "A2",
        title: "Pull-cord light",
        summary: "A limp tug does nothing. A proper yank toggles the bulb.",
        section: .coreMotion,
        hardware: "Touch velocity  ·  optional tilt",
        symbol: "lightbulb",
        coaching: "Yank the handle. A slow stretch fails on purpose."
    ) {
        PullCordView()
    }

    static let compassMercury = ExperimentDescriptor(
        id: "compass-mercury",
        code: "A3",
        title: "Compass mercury",
        summary: "A magnetometer blob that sits on true north.",
        section: .coreMotion,
        hardware: "Magnetometer  ·  location for true north",
        symbol: "location.north.line",
        coaching: "Turn the phone. The blob rests on north."
    ) {
        CompassMercuryView()
    }

    static let barometricBalloon = ExperimentDescriptor(
        id: "barometric-balloon",
        code: "A4",
        title: "Barometric balloon",
        summary: "Lift the phone; the balloon rises with air pressure.",
        section: .coreMotion,
        hardware: "CMAltimeter  ·  drag fallback",
        symbol: "balloon",
        coaching: "Lift the phone about a foot. Drag if there’s no barometer."
    ) {
        BarometricBalloonView()
    }

    static let safeDial = ExperimentDescriptor(
        id: "safe-dial",
        code: "B5",
        title: "Safe dial",
        summary: "Rotational detents. A click per notch, a heavy clunk at the drop.",
        section: .haptics,
        hardware: "Core Haptics",
        symbol: "lock.rotation",
        coaching: "Turn the dial. The drop clunks open."
    ) {
        SafeDialView()
    }

    static let zipper = ExperimentDescriptor(
        id: "zipper",
        code: "B6",
        title: "Zipper",
        summary: "Pull the slider. Each tooth ticks.",
        section: .haptics,
        hardware: "Core Haptics",
        symbol: "slider.vertical.3",
        coaching: "Pull the tab. Every tooth ticks."
    ) {
        ZipperView()
    }

    static let matchbook = ExperimentDescriptor(
        id: "matchbook",
        code: "B7",
        title: "Matchbook strike",
        summary: "Velocity-gated ignition. Slow scrapes are supposed to fail.",
        section: .haptics,
        hardware: "Touch velocity  ·  haptics",
        symbol: "flame",
        coaching: "Strike fast along the grit. Slow is just a scrape."
    ) {
        MatchbookView()
    }

    static let waxSeal = ExperimentDescriptor(
        id: "wax-seal",
        code: "B8",
        title: "Wax seal",
        summary: "Hold to melt. Release to stamp.",
        section: .haptics,
        hardware: "Press duration  ·  haptics",
        symbol: "checkmark.seal",
        coaching: "Press and hold until the pool is ready. Release to stamp."
    ) {
        WaxSealView()
    }

    static let faceSpecular = ExperimentDescriptor(
        id: "face-specular",
        code: "C9",
        title: "Face-tracked specular",
        summary: "TrueDepth eye position drives a metal highlight.",
        section: .sensors,
        hardware: "TrueDepth / ARKit  ·  tilt fallback",
        symbol: "sparkle",
        coaching: "Move your head. The highlight follows your eyes."
    ) {
        FaceSpecularView()
    }

    static let parallaxDiorama = ExperimentDescriptor(
        id: "parallax-diorama",
        code: "C10",
        title: "Parallax diorama",
        summary: "Head-tracked off-axis projection through a little room.",
        section: .sensors,
        hardware: "TrueDepth / ARKit  ·  tilt fallback",
        symbol: "cube.transparent",
        coaching: "Lean left or right. The room is off-axis."
    ) {
        ParallaxDioramaView()
    }

    static let chladniPlate = ExperimentDescriptor(
        id: "chladni-plate",
        code: "C11",
        title: "Chladni plate",
        summary: "Mic FFT settles sand on standing-wave nodes.",
        section: .sensors,
        hardware: "Microphone  ·  drag-to-tone fallback",
        symbol: "waveform",
        coaching: "Hum a tone. Sand finds the nodes."
    ) {
        ChladniPlateView()
    }

    static let metaballMercury = ExperimentDescriptor(
        id: "metaball-mercury",
        code: "D12",
        title: "Metaball mercury",
        summary: "SDF blobs merged with a smooth minimum.",
        section: .shaders,
        hardware: "Metal  ·  touch + tilt",
        symbol: "drop",
        coaching: "Drag a blob. Tilt to let them merge."
    ) {
        MetaballMercuryView()
    }

    static let soapFilm = ExperimentDescriptor(
        id: "soap-film",
        code: "D13",
        title: "Soap film",
        summary: "Thin-film iridescence from tilt, then a pop.",
        section: .shaders,
        hardware: "Metal  ·  CoreMotion",
        symbol: "circle.dotted",
        coaching: "Tilt for color. Tap to pop."
    ) {
        SoapFilmView()
    }

    static let inkBleed = ExperimentDescriptor(
        id: "ink-bleed",
        code: "D14",
        title: "Ink bleed",
        summary: "Touch diffusion into paper grain.",
        section: .shaders,
        hardware: "Touch",
        symbol: "paintbrush.pointed",
        coaching: "Touch the paper. Ink follows the grain."
    ) {
        InkBleedView()
    }

    static let frost = ExperimentDescriptor(
        id: "frost",
        code: "D15",
        title: "Frost",
        summary: "Dendritic ice growing from a fingertip.",
        section: .shaders,
        hardware: "Touch",
        symbol: "snowflake",
        coaching: "Touch the pane. Ice ferns out."
    ) {
        FrostView()
    }

    static let smokeBox = ExperimentDescriptor(
        id: "smoke-box",
        code: "E16",
        title: "Smoke box",
        summary: "Stable fluids. Tilt is gravity; a finger is force.",
        section: .simulation,
        hardware: "CoreMotion  ·  touch",
        symbol: "smoke",
        coaching: "Drag to stir. Tilt is gravity."
    ) {
        SmokeBoxView()
    }

    static let clothPanel = ExperimentDescriptor(
        id: "cloth-panel",
        code: "E17",
        title: "Cloth panel",
        summary: "Mass-spring sheet. Motion plus drag.",
        section: .simulation,
        hardware: "CoreMotion  ·  touch",
        symbol: "square.grid.3x3",
        coaching: "Drag the cloth. Tilt the phone."
    ) {
        ClothPanelView()
    }

    static let ironFilings = ExperimentDescriptor(
        id: "iron-filings",
        code: "E18",
        title: "Iron filings",
        summary: "A vector field. Your finger is a magnetic pole.",
        section: .simulation,
        hardware: "Touch",
        symbol: "location.north",
        coaching: "Hold a pole. Filings align to the field."
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
