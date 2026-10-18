import Foundation

// MARK: - Modèle JSON
// ⚠️ DEVINÉ : le Kotlin passe par analyticsItemsToJson(item), que je n'ai pas pu lire
// (ni AnalyticsItem). La doc confirme seulement : nom d'événement, propriétés clé/valeur,
// horodatage et flux. Les noms de clés ci-dessous sont à comparer avec le mapper ;
// tout est regroupé ici.

struct FloconAnalyticsItemRemote: Encodable {
    let id: String
    let analyticsTableId: String
    let eventName: String
    let createdAt: Int64
    let properties: [Property]

    struct Property: Encodable {
        let name: String
        let value: String
    }
}
