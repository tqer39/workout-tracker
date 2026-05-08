import CoreGraphics
import Foundation

struct Checkpoint: Identifiable, Equatable {
    let id: String
    let name: String
    let cumulativeKm: Double
    let mapPosition: CGPoint
    let blurb: String
    let badgeAssetName: String
}

enum JourneyRoute {
    static let totalKm: Double = 1150

    static let tokyoToHakata: [Checkpoint] = [
        .init(id: "tokyo", name: "東京", cumulativeKm: 0,
              mapPosition: .init(x: 0.78, y: 0.45),
              blurb: "旅のはじまり。日本橋を出発、東海道五十三次の起点。",
              badgeAssetName: "Badges/tokyo"),
        .init(id: "yokohama", name: "横浜", cumulativeKm: 30,
              mapPosition: .init(x: 0.76, y: 0.47),
              blurb: "港の街、開国の窓口。中華街と赤レンガ倉庫が見もの。",
              badgeAssetName: "Badges/yokohama"),
        .init(id: "atami", name: "熱海", cumulativeKm: 105,
              mapPosition: .init(x: 0.70, y: 0.50),
              blurb: "温泉と海を一度に楽しめる保養地。花火大会も有名。",
              badgeAssetName: "Badges/atami"),
        .init(id: "shizuoka", name: "静岡", cumulativeKm: 180,
              mapPosition: .init(x: 0.65, y: 0.52),
              blurb: "富士山を望む茶どころ。駿河湾の海の幸も豊富。",
              badgeAssetName: "Badges/shizuoka"),
        .init(id: "hamamatsu", name: "浜松", cumulativeKm: 260,
              mapPosition: .init(x: 0.60, y: 0.54),
              blurb: "うなぎと餃子の街。楽器産業の発祥地でもある。",
              badgeAssetName: "Badges/hamamatsu"),
        .init(id: "nagoya", name: "名古屋", cumulativeKm: 365,
              mapPosition: .init(x: 0.55, y: 0.55),
              blurb: "金鯱の街。ひつまぶし・味噌カツ・きしめんの食文化。",
              badgeAssetName: "Badges/nagoya"),
        .init(id: "kyoto", name: "京都", cumulativeKm: 515,
              mapPosition: .init(x: 0.49, y: 0.56),
              blurb: "千年の都。寺社仏閣と路地裏の風情、四季の美しさ。",
              badgeAssetName: "Badges/kyoto"),
        .init(id: "osaka", name: "大阪", cumulativeKm: 555,
              mapPosition: .init(x: 0.46, y: 0.57),
              blurb: "天下の台所。たこ焼き・お好み焼き・串カツの聖地。",
              badgeAssetName: "Badges/osaka"),
        .init(id: "kobe", name: "神戸", cumulativeKm: 590,
              mapPosition: .init(x: 0.44, y: 0.58),
              blurb: "港町と異人館。神戸ビーフと夜景の街。",
              badgeAssetName: "Badges/kobe"),
        .init(id: "okayama", name: "岡山", cumulativeKm: 730,
              mapPosition: .init(x: 0.36, y: 0.61),
              blurb: "桃太郎伝説と倉敷の白壁。瀬戸内の温暖な気候。",
              badgeAssetName: "Badges/okayama"),
        .init(id: "hiroshima", name: "広島", cumulativeKm: 890,
              mapPosition: .init(x: 0.28, y: 0.64),
              blurb: "平和記念都市と宮島。お好み焼きと牡蠣の名物。",
              badgeAssetName: "Badges/hiroshima"),
        .init(id: "shimonoseki", name: "下関", cumulativeKm: 1075,
              mapPosition: .init(x: 0.21, y: 0.67),
              blurb: "本州の最西端、ふくの本場。関門海峡を望む。",
              badgeAssetName: "Badges/shimonoseki"),
        .init(id: "hakata", name: "博多", cumulativeKm: 1150,
              mapPosition: .init(x: 0.18, y: 0.70),
              blurb: "旅のゴール。豚骨ラーメンと屋台、めんたいこの本場。",
              badgeAssetName: "Badges/hakata"),
    ]
}
