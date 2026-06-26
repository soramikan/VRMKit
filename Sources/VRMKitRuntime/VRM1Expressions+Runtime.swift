import VRMKit

package extension VRM1.Expressions {
    var runtimeClips: [(name: String, preset: ExpressionPreset?, expression: VRM1.Expressions.Expression)] {
        let presetClips: [(ExpressionPreset, VRM1.Expressions.Expression)] = [
            (.happy, preset.happy),
            (.angry, preset.angry),
            (.sad, preset.sad),
            (.relaxed, preset.relaxed),
            (.surprised, preset.surprised),
            (.aa, preset.aa),
            (.ih, preset.ih),
            (.ou, preset.ou),
            (.ee, preset.ee),
            (.oh, preset.oh),
            (.blink, preset.blink),
            (.blinkLeft, preset.blinkLeft),
            (.blinkRight, preset.blinkRight),
            (.lookUp, preset.lookUp),
            (.lookDown, preset.lookDown),
            (.lookLeft, preset.lookLeft),
            (.lookRight, preset.lookRight),
            (.neutral, preset.neutral)
        ]
        var clips: [(String, ExpressionPreset?, VRM1.Expressions.Expression)] = presetClips.map { expressionPreset, expression in
            (expressionPreset.rawValue, expressionPreset, expression)
        }

        guard let customMap = custom?.value as? [String: Any] else {
            return clips
        }

        let decoder = DictionaryDecoder()
        for name in customMap.keys.sorted() {
            guard let raw = customMap[name] as? [String: Any],
                  let expression = try? decoder.decode(VRM1.Expressions.Expression.self, from: raw) else {
                continue
            }
            clips.append((name, nil, expression))
        }
        return clips
    }
}
