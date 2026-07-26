//
//  CardFieldsView.swift
//  VisiteScan
//
//  Stap 6: die uitslag as 'n veldlys in Contacts se volgorde, waar 'n reël wat
//  verkeerd geplaas is na die regte veld geskuif word.
//
//  Twee maniere om te skuif, doelbewus albei:
//
//  1. **Sleep** aan die driestrepie-handvatsel — dit is wat Erich gevra het, en
//     dit is die vinnigste as 'n mens die lys sien.
//  2. **Tik** op die veldnaam regs — 'n kieslys van al die velde. Sleep tussen
//     afdelings in 'n List is fyn werk met 'n duim; hierdie een mis nooit.
//
//  Die twee is nie oorbodig nie: die sleep is die gebaar wat lekker voel, die
//  kieslys die een wat werk wanneer die kaartjie lank is en die regte veld
//  buite die skerm lê.
//

import SwiftUI

struct CardFieldsView: View {

    @Binding var assignments: [LineAssignment]

    /// Die reël wat nou gesleep word — sodat sy ry dof word terwyl hy "weg" is.
    @State private var draggingID: UUID?

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

        // Alles wat die ontleder nie kon plaas nie. Dit is nie 'n fout nie —
        // 'n kaartjie het altyd teks wat in geen veld hoort nie (slagspreuke,
        // registrasienommers). Maar dit is ook waar 'n gemiste veld skuil.
        Section {
            fieldRow(.unused)
        } header: {
            Text("Nie gebruik nie")
        } footer: {
            Text("Sleep aan ≡ om 'n reël na 'n ander veld te skuif, of tik regs op die veldnaam. Tik op die teks self om 'n OCR-fout reg te maak.")
        }
    }

    // MARK: Een veld

    @ViewBuilder
    private func fieldRow(_ field: CardField) -> some View {
        let rows = assignments.lines(for: field)

        VStack(alignment: .leading, spacing: 6) {
            Label(field.label, systemImage: field.icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            if rows.isEmpty {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            } else {
                ForEach(rows) { row in
                    lineRow(row, in: field)
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            receive(items, into: field)
        }
    }

    // MARK: Een reël

    private func lineRow(_ row: LineAssignment, in field: CardField) -> some View {
        HStack(spacing: 10) {

            // Die handvatsel. Dit is die sleepbare deel — nie die hele ry nie,
            // want die teks moet tikbaar bly om te wysig.
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 24, height: 32)
                .contentShape(Rectangle())
                .draggable(row.id.uuidString) {
                    Text(row.text)
                        .padding(8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

            TextField(field.label, text: binding(for: row.id))
                .font(.callout)
                .textInputAutocapitalization(field.capitalization)
                .keyboardType(field.keyboard)

            Menu {
                Picker("Skuif na", selection: fieldBinding(for: row.id)) {
                    ForEach(CardField.allCases) { target in
                        Label(target.label, systemImage: target.icon).tag(target)
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .opacity(draggingID == row.id ? 0.4 : 1)
    }

    // MARK: Skuif

    private func receive(_ items: [String], into field: CardField) -> Bool {
        guard let first = items.first,
              let id = UUID(uuidString: first),
              let index = assignments.firstIndex(where: { $0.id == id }),
              assignments[index].field != field else { return false }

        withAnimation(.snappy) { assignments[index].field = field }
        return true
    }

    // MARK: Bindings

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { assignments.first { $0.id == id }?.text ?? "" },
            set: { newValue in
                guard let index = assignments.firstIndex(where: { $0.id == id }) else { return }
                assignments[index].text = newValue
            }
        )
    }

    private func fieldBinding(for id: UUID) -> Binding<CardField> {
        Binding(
            get: { assignments.first { $0.id == id }?.field ?? .unused },
            set: { newValue in
                guard let index = assignments.firstIndex(where: { $0.id == id }) else { return }
                withAnimation(.snappy) { assignments[index].field = newValue }
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
