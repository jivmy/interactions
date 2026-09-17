import SwiftUI

enum ExperimentSection: String, CaseIterable, Identifiable {
    case coreMotion = "A  ·  CoreMotion"
    case haptics = "B  ·  Haptics"
    case sensors = "C  ·  Sensors"
    case shaders = "D  ·  Shaders"
    case simulation = "E  ·  Simulation"

    var id: String { rawValue }

    var blurb: String {
        switch self {
        case .coreMotion: "Gravity, compass, air pressure"
        case .haptics: "Clicks, ticks, strikes"
        case .sensors: "Face, head, microphone"
        case .shaders: "Metal and diffusion"
        case .simulation: "Fluids, cloth, fields"
        }
    }
}

/// One entry in Jimmy’s interaction lab.
struct ExperimentDescriptor: Identifiable {
    let id: String
    let code: String
    let title: String
    let summary: String
    let section: ExperimentSection
    let hardware: String
    let makeView: () -> AnyView

    init<V: View>(
        id: String,
        code: String,
        title: String,
        summary: String,
        section: ExperimentSection,
        hardware: String,
        @ViewBuilder content: @escaping () -> V
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.summary = summary
        self.section = section
        self.hardware = hardware
        self.makeView = { AnyView(content()) }
    }
}

enum ExperimentCatalog {
    static let hangingChain = ExperimentDescriptor(
        id: "hanging-chain",
        code: "A1",
        title: "Hanging chain",
        summary: "Verlet rope pinned at the top, swung by real device gravity.",
        section: .coreMotion,
        hardware: "CoreMotion  ·  drag on Simulator"
    ) {
        HangingChainView()
    }

    static let pullCord = ExperimentDescriptor(
        id: "pull-cord",
        code: "A2",
        title: "Pull-cord light",
        summary: "A limp tug does nothing. A proper yank toggles the bulb.",
        section: .coreMotion,
        hardware: "Touch velocity  ·  optional tilt"
    ) {
        PullCordView()
    }

    static let compassMercury = ExperimentDescriptor(
        id: "compass-mercury",
        code: "A3",
        title: "Compass mercury",
        summary: "A magnetometer blob that sits on true north.",
        section: .coreMotion,
        hardware: "Magnetometer  ·  location for true north"
    ) {
        CompassMercuryView()
    }

    static let barometricBalloon = ExperimentDescriptor(
        id: "barometric-balloon",
        code: "A4",
        title: "Barometric balloon",
        summary: "Lift the phone; the balloon rises with air pressure.",
        section: .coreMotion,
        hardware: "CMAltimeter  ·  drag fallback"
    ) {
        BarometricBalloonView()
    }

    static let safeDial = ExperimentDescriptor(
        id: "safe-dial",
        code: "B5",
        title: "Safe dial",
        summary: "Rotational detents. A click per notch, a heavy clunk at the drop.",
        section: .haptics,
        hardware: "Core Haptics"
    ) {
        SafeDialView()
    }

    static let zipper = ExperimentDescriptor(
        id: "zipper",
        code: "B6",
        title: "Zipper",
        summary: "Pull the slider. Each tooth ticks.",
        section: .haptics,
        hardware: "Core Haptics"
    ) {
        ZipperView()
    }

    static let matchbook = ExperimentDescriptor(
        id: "matchbook",
        code: "B7",
        title: "Matchbook strike",
        summary: "Velocity-gated ignition. Slow scrapes are supposed to fail.",
        section: .haptics,
        hardware: "Touch velocity  ·  haptics"
    ) {
        MatchbookView()
    }

    static let waxSeal = ExperimentDescriptor(
        id: "wax-seal",
        code: "B8",
        title: "Wax seal",
        summary: "Hold to melt. Release to stamp.",
        section: .haptics,
        hardware: "Press duration  ·  haptics"
    ) {
        WaxSealView()
    }

    static let faceSpecular = ExperimentDescriptor(
        id: "face-specular",
        code: "C9",
        title: "Face-tracked specular",
        summary: "TrueDepth eye position drives a metal highlight.",
        section: .sensors,
        hardware: "TrueDepth / ARKit  ·  tilt fallback"
    ) {
        FaceSpecularView()
    }

    static let parallaxDiorama = ExperimentDescriptor(
        id: "parallax-diorama",
        code: "C10",
        title: "Parallax diorama",
        summary: "Head-tracked off-axis projection through a little room.",
        section: .sensors,
        hardware: "TrueDepth / ARKit  ·  tilt fallback"
    ) {
        ParallaxDioramaView()
    }

    static let chladniPlate = ExperimentDescriptor(
        id: "chladni-plate",
        code: "C11",
        title: "Chladni plate",
        summary: "Mic FFT settles sand on standing-wave nodes.",
        section: .sensors,
        hardware: "Microphone  ·  drag-to-tone fallback"
    ) {
        ChladniPlateView()
    }

    static let metaballMercury = ExperimentDescriptor(
        id: "metaball-mercury",
        code: "D12",
        title: "Metaball mercury",
        summary: "SDF blobs merged with a smooth minimum.",
        section: .shaders,
        hardware: "Metal  ·  touch + tilt"
    ) {
        MetaballMercuryView()
    }

    static let soapFilm = ExperimentDescriptor(
        id: "soap-film",
        code: "D13",
        title: "Soap film",
        summary: "Thin-film iridescence from tilt, then a pop.",
        section: .shaders,
        hardware: "Metal  ·  CoreMotion"
    ) {
        SoapFilmView()
    }

    static let inkBleed = ExperimentDescriptor(
        id: "ink-bleed",
        code: "D14",
        title: "Ink bleed",
        summary: "Touch diffusion into paper grain.",
        section: .shaders,
        hardware: "Touch"
    ) {
        InkBleedView()
    }

    static let frost = ExperimentDescriptor(
        id: "frost",
        code: "D15",
        title: "Frost",
        summary: "Dendritic ice growing from a fingertip.",
        section: .shaders,
        hardware: "Touch"
    ) {
        FrostView()
    }

    static let smokeBox = ExperimentDescriptor(
        id: "smoke-box",
        code: "E16",
        title: "Smoke box",
        summary: "Stable fluids. Tilt is gravity; a finger is force.",
        section: .simulation,
        hardware: "CoreMotion  ·  touch"
    ) {
        SmokeBoxView()
    }

    static let clothPanel = ExperimentDescriptor(
        id: "cloth-panel",
        code: "E17",
        title: "Cloth panel",
        summary: "Mass-spring sheet. Motion plus drag.",
        section: .simulation,
        hardware: "CoreMotion  ·  touch"
    ) {
        ClothPanelView()
    }

    static let ironFilings = ExperimentDescriptor(
        id: "iron-filings",
        code: "E18",
        title: "Iron filings",
        summary: "A vector field. Your finger is a magnetic pole.",
        section: .simulation,
        hardware: "Touch"
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
}
