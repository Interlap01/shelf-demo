import SwiftUI

@main
struct ShelfApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.ink)
        }
    }
}

extension Color {
    static let ink = Color(red: 0.08, green: 0.10, blue: 0.13)
    static let paper = Color(red: 0.96, green: 0.95, blue: 0.93)
}

struct Product: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let price: Decimal
    let symbol: String
    let tint: Color
}

struct CartLine: Identifiable {
    let product: Product
    var quantity: Int
    var id: String { product.id }
    var total: Decimal { product.price * Decimal(quantity) }
}

@Observable
@MainActor
final class Store {
    var userName: String?
    var lines: [CartLine] = []
    var orderPlaced = false

    let catalog: [Product] = [
        Product(id: "mug", name: "Ceramic mug", detail: "Stoneware, 350 ml", price: 18, symbol: "cup.and.saucer.fill", tint: .orange),
        Product(id: "tote", name: "Canvas tote", detail: "Heavy cotton, natural", price: 24, symbol: "bag.fill", tint: .brown),
        Product(id: "notebook", name: "Dot notebook", detail: "A5, 160 pages", price: 12, symbol: "book.closed.fill", tint: .teal),
        Product(id: "candle", name: "Cedar candle", detail: "Soy wax, 40 hours", price: 22, symbol: "flame.fill", tint: .red),
        Product(id: "plant", name: "Desk plant", detail: "Pothos in a clay pot", price: 16, symbol: "leaf.fill", tint: .green),
        Product(id: "lamp", name: "Reading lamp", detail: "Warm LED, dimmable", price: 39, symbol: "lamp.desk.fill", tint: .indigo),
    ]

    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }
    var total: Decimal { lines.reduce(0) { $0 + $1.total } }

    func signIn(email: String) {
        let local = email.split(separator: "@").first.map(String.init) ?? "there"
        userName = local.prefix(1).uppercased() + local.dropFirst()
    }

    func add(_ product: Product) {
        if let i = lines.firstIndex(where: { $0.product == product }) {
            lines[i].quantity += 1
        } else {
            lines.append(CartLine(product: product, quantity: 1))
        }
    }

    func quantity(of product: Product) -> Int {
        lines.first { $0.product == product }?.quantity ?? 0
    }

    func remove(_ line: CartLine) {
        lines.removeAll { $0.id == line.id }
    }

    func checkout() {
        lines.removeAll()
        orderPlaced = true
    }
}

func price(_ value: Decimal) -> String {
    value.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
}

extension ShapeStyle where Self == Color {
    static var ink: Color { Color.ink }
}
