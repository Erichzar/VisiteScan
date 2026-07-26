//
//  CardFieldsView.swift
//  VisiteScan
//
//  Stap 6: twee kolomme.
//
//      ┌──────────┬────────────────────────┐
//      │ Naam     │ Park Str             ≡ │
//      │ Firma    │ Piet Lutz            ≡ │
//      │ E-pos    │ piet@…               ≡ │
//      └──────────┴────────────────────────┘
//      ┌──────────┬────────────────────────┐
//      │ Temp     │ die res              ≡ │
//      └──────────┴────────────────────────┘
//
//  Links die vaste veldname — hulle beweeg nooit. Regs die gelese waardes, wat
//  aan die ≡ na 'n ander veld gesleep word. Sit daar klaar iets, word dít na
//  Temp verdring; die twee bewegings is een gebaar.
//
//  Temp is 'n parkeerplek, nie 'n asblik nie. 'n Waarde wat daar beland, wag om
//  later geplaas te word — en 'n kaartjie het altyd teks wat nêrens hoort nie
//  (slagspreuke, registrasienommers), so Temp is ook nie 'n foutlys nie.
//

import SwiftUI

struct CardFieldsView: View {

    @Binding var values: [CardValue]

    /// Die waarde wat nou gesleep word, sodat sy ry dof word terwyl hy "weg" is.
    @State private var dragging: UUID?

    private let labelWidth: CGFloat = 88

    var body: some View {

        ForEach(CardField.groups, id: \.title) { group in
            Section {
                ForEach(group.fields) { field in
                    fieldRow(field)
                }
            } header: {
                Text(group.title)
            }
        }

        workbench(.temp,
                  hint: "Sleep aan ≡ om 'n waarde na 'n ander veld te skuif — wat daar was, kom hierheen. Tik op die teks self om 'n leesfout reg te maak.")

        workbench(.combo,
                  hint: "Sleep twee waardes hierheen en hulle smelt saam tot een — vir wanneer 'n adres of naam oor twee reëls geloop het. Sleep die resultaat dan na sy veld.")
    }

    // MARK: Werkbanke — Temp en Kombo

    @ViewBuilder
    private func workbench(_ field: CardField, hint: String) -> some View {
        Section {
            let parked = values.values(in: field)
            if parked.isEmpty {
                emptyRow(field)
            } else {
                ForEach(parked) { value in
                    row(field: field, value: value)
                }
            }
        } header: {
            Text(field.label)
        } footer: {
            Text(hint)
        }
    }

    // MARK: Een veld

    @ViewBuilder
    private func fieldRow(_ field: CardField) -> some View {
        if let value = values.value(in: field) {
            row(field: field, value: value)
        } else {
            emptyRow(field)
        }
    }

    private func row(field: CardField, value: CardValue) -> some View {
        HStack(spacing: 8) {
            label(field)

            TextField(field.label, text: binding(for: value.id))
                .font(.callout)
                .keyboardType(field.keyboard)
                .textInputAutocapitalization(field.capitalization)

            handle(value)
        }
        .opacity(dragging == value.id ? 0.35 : 1)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            accept(items, into: field)
        }
    }

    private func emptyRow(_ field: CardField) -> some View {
        HStack(spacing: 8) {
            label(field)

            Text("—")
                .font(.callout)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            accept(items, into: field)
        }
    }

    // MARK: Onderdele

    /// Die vaste kolom links. Vaste breedte, sodat die kolom 'n reguit lyn vorm
    /// waarteen 'n mens kan mik terwyl jy sleep.
    private func label(_ field: CardField) -> some View {
        Label {
            Text(field.label)
        } icon: {
            Image(systemName: field.icon)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(width: labelWidth, alignment: .leading)
    }

    /// Net die handvatsel sleep — die teks moet tikbaar bly om te wysig.
    private func handle(_ value: CardValue) -> some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.tertiary)
            .frame(width: 32, height: 34)
            .contentShape(Rectangle())
            .draggable(value.id.uuidString) {
                Text(value.text)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }
    }

    // MARK: Skuif

    private func accept(_ items: [String], into field: CardField) -> Bool {
        guard let first = items.first, let id = UUID(uuidString: first) else { return false }
        withAnimation(.snappy) { values.move(id, to: field) }
        return true
    }

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { values.first { $0.id == id }?.text ?? "" },
            set: { newText in
                guard let index = values.firstIndex(where: { $0.id == id }) else { return }
                values[index].text = newText
            }
        )
    }
}

// MARK: - Sleutelbord per veld

private extension CardField {

    var keyboard: UIKeyboardType {
        switch self {
        case .mobile, .phone: .phonePad
        case .postalCode:     .numberPad
        case .email:          .emailAddress
        case .website:        .URL
        default:              .default
        }
    }

    var capitalization: TextInputAutocapitalization {
        switch self {
        case .email, .website: .never
        default:               .words
        }
    }
}
