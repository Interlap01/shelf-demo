import SwiftUI

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        if store.userName == nil {
            NavigationStack { WelcomeView() }
        } else {
            MainTabs()
        }
    }
}

// MARK: - Sign in

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "basket.fill")
                .font(.system(size: 56))
                .foregroundStyle(.ink)
                .frame(width: 112, height: 112)
                .background(.white, in: .rect(cornerRadius: 28))
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(.ink, lineWidth: 2))
            Text("Shelf")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
            Text("Small goods for slow mornings.")
                .foregroundStyle(.secondary)
            Spacer()
            NavigationLink("Sign in") { SignInView() }
                .buttonStyle(PrimaryButton())
            Text("New here? Create an account")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.paper)
    }
}

struct SignInView: View {
    @Environment(Store.self) private var store
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            Text("Use the email you shop with.")
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .fieldStyle()
                SecureField("Password", text: $password)
                    .fieldStyle()
            }
            .padding(.top, 8)
            Button("Get started") { store.signIn(email: email) }
                .buttonStyle(PrimaryButton())
                .disabled(email.isEmpty)
                .padding(.top, 8)
            Spacer()
        }
        .padding(24)
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shop

struct MainTabs: View {
    @Environment(Store.self) private var store

    var body: some View {
        TabView {
            Tab("Shop", systemImage: "square.grid.2x2") {
                NavigationStack { ShopView() }
            }
            Tab("Cart", systemImage: "cart") {
                NavigationStack { CartView() }
            }
            .badge(store.itemCount)
        }
    }
}

struct ShopView: View {
    @Environment(Store.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Welcome, \(store.userName ?? "")")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                FreeShippingProgressBar(
                    progress: store.freeShippingProgress,
                    remaining: store.amountToFreeShipping,
                    unlocked: store.hasFreeShipping
                )
                if store.itemCount > 0 {
                    Label("\(store.itemCount) \(store.itemCount == 1 ? "item" : "items") in your cart", systemImage: "cart.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.15), in: .capsule)
                        .foregroundStyle(.green)
                }
                Text("New this week")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                ForEach(store.catalog) { product in
                    ProductRow(product: product)
                }
            }
            .padding(20)
        }
        .background(Color.paper)
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FreeShippingProgressBar: View {
    let progress: Double
    let remaining: Decimal
    let unlocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: unlocked ? "shippingbox.fill" : "shippingbox")
                    .accessibilityHidden(true)
                Text(unlocked
                     ? "Free shipping unlocked"
                     : "\(price(remaining)) away from free shipping")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text("over \(price(Store.freeShippingThreshold))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.ink.opacity(0.12))
                    Capsule()
                        .fill(unlocked ? Color.green : Color.ink)
                        .frame(width: max(geo.size.width * progress, progress > 0 ? 8 : 0))
                        .animation(.easeInOut(duration: 0.35), value: progress)
                }
            }
            .frame(height: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(unlocked
                ? "Free shipping unlocked"
                : "\(price(remaining)) away from free shipping")
            .accessibilityValue("\(Int((progress * 100).rounded())) percent")
        }
        .padding(14)
        .background(.white, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.ink.opacity(0.9), lineWidth: 1.5))
    }
}

struct ProductRow: View {
    @Environment(Store.self) private var store
    let product: Product

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: product.symbol)
                .font(.title2)
                .foregroundStyle(product.tint)
                .frame(width: 56, height: 56)
                .background(product.tint.opacity(0.14), in: .rect(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(product.name).font(.headline)
                Text(product.detail).font(.subheadline).foregroundStyle(.secondary)
                Text(price(product.price)).font(.subheadline.weight(.semibold))
            }
            Spacer()
            if store.quantity(of: product) > 0 {
                Label("Added", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button {
                    store.add(product)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(.ink, in: .circle)
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Add \(product.name) to cart")
            }
        }
        .padding(12)
        .background(.white, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.ink.opacity(0.9), lineWidth: 1.5))
    }
}

// MARK: - Cart

struct CartView: View {
    @Environment(Store.self) private var store

    var body: some View {
        Group {
            if store.lines.isEmpty {
                ContentUnavailableView(
                    store.orderPlaced ? "Order placed" : "Your cart is empty",
                    systemImage: store.orderPlaced ? "checkmark.seal" : "cart",
                    description: Text(store.orderPlaced ? "Thanks! We'll email your receipt." : "Add something from the shop.")
                )
            } else {
                List {
                    Section {
                        ForEach(store.lines) { line in
                            HStack {
                                Image(systemName: line.product.symbol)
                                    .foregroundStyle(line.product.tint)
                                    .frame(width: 32)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading) {
                                    Text(line.product.name)
                                    Text("Qty \(line.quantity)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(price(line.total)).monospacedDigit()
                            }
                            .swipeActions { Button("Remove", role: .destructive) { store.remove(line) } }
                        }
                    }
                    Section {
                        HStack {
                            Text("Total").font(.headline)
                            Spacer()
                            Text(price(store.total)).font(.headline).monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Section {
                        Button("Checkout") { store.checkout() }
                            .buttonStyle(PrimaryButton())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.paper)
        .navigationTitle("Cart")
    }
}

// MARK: - Styles

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(.ink, in: .rect(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    func fieldStyle() -> some View {
        padding(14)
            .background(.white, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.ink.opacity(0.25), lineWidth: 1))
    }
}
