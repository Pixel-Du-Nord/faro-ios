#if canImport(UIKit) && os(iOS)
import Faro
import Foundation

/**
 Every text of ``FaroHelpView`` that does not come from the Faro panel.

 The form's own texts (title, intro, labels, options, the send button, the
 success message) are written by your team in Faro and win; these are the names
 of the request kinds, hints, notices, buttons and fallbacks. Built in:
 ``english``, ``spanish`` and ``portuguese`` (``forLocale(_:)``). For another
 language, or your own wording, copy one and change what you need:

 ```swift
 var strings = FaroStrings.english
 strings.kindProblem = "Report a bug"
 FaroHelpView(strings: strings) { showHelp = false }
 ```

 Texts with `%d` and `%@` are formatted with the values described on each property.
 */
public struct FaroStrings: Sendable, Hashable {
    public var helpTitle: String
    public var defaultIntro: String
    public var close: String
    public var kindHeading: String
    public var kindProblem: String
    public var kindSuggestion: String
    public var kindQuestion: String
    public var kindProblemHint: String
    public var kindSuggestionHint: String
    public var kindQuestionHint: String
    public var kindPrompt: String
    public var nameLabel: String
    public var emailLabel: String
    public var emailHelp: String
    public var emailPlaceholder: String
    public var messageLabel: String
    public var messagePlaceholder: String
    public var optional: String
    public var chooseOption: String
    public var chooseDate: String
    public var clear: String
    public var issueRequired: String
    public var issueKind: String
    public var issueEmail: String
    public var issueShort: String
    public var issueLong: String
    public var issueInvalid: String
    public var attachmentsHeading: String
    public var screenshotCaption: String
    public var screenshotIncluded: String
    public var screenshotExcluded: String
    public var coverPrivate: String
    public var screenshotPreview: String
    public var addPhotos: String
    /// `%d` attached, `%d` maximum.
    public var attachmentsCount: String
    public var removeImage: String
    public var editorHint: String
    /// VoiceOver description of the drawing area.
    public var editorCanvas: String
    /// The thick marker that covers what is under it.
    public var toolCover: String
    /// A filled box, for whole lines or areas.
    public var toolBox: String
    /// A thin pen in the accent color, to point at what went wrong.
    public var toolMark: String
    public var undo: String
    public var cancel: String
    public var done: String
    public var sentWith: String
    public var sentWithDetail: String
    public var recentActions: String
    public var send: String
    public var sending: String
    public var noticeOffline: String
    public var noticeRateLimited: String
    public var noticeFailed: String
    public var noticeAttachment: String
    public var noticeUnavailable: String
    public var offlineTitle: String
    public var offlineBody: String
    public var retry: String
    public var statusConnecting: String
    public var statusCached: String
    public var statusOffline: String
    /// `%d` the request number.
    public var successTitle: String
    public var successDefault: String
    /// `%@` the email, `%d` the request number.
    public var successReplies: String
    public var successConfirm: String
    public var sendAnother: String

    /// The built-in texts for a language (`"es"`, `"pt-BR"`…); English for anything else.
    public static func forLocale(_ locale: String?) -> FaroStrings {
        switch FaroLocale.language(locale) {
        case "es": return .spanish
        case "pt": return .portuguese
        default: return .english
        }
    }

    /// The name people read for `kind`.
    public func kindName(_ kind: FaroKind) -> String {
        switch kind {
        case .problem: return kindProblem
        case .suggestion: return kindSuggestion
        case .question: return kindQuestion
        default: return kind.rawValue.capitalized
        }
    }

    /// One line saying what `kind` is for.
    public func kindHint(_ kind: FaroKind) -> String {
        switch kind {
        case .problem: return kindProblemHint
        case .suggestion: return kindSuggestionHint
        case .question: return kindQuestionHint
        default: return ""
        }
    }

    func issue(_ issue: FaroFieldIssue, key: String) -> String {
        switch issue {
        case .required: return key == FaroForm.kindKey ? issueKind : issueRequired
        case .invalidEmail: return issueEmail
        case .tooShort: return issueShort
        case .tooLong: return issueLong
        case .invalid: return issueInvalid
        }
    }

    public static let english = FaroStrings(
        helpTitle: "Help & feedback",
        defaultIntro: "Tell us what happened. We read everything and reply by email.",
        close: "Close",
        kindHeading: "What is it about?",
        kindProblem: "Something's wrong",
        kindSuggestion: "An idea",
        kindQuestion: "A question",
        kindProblemHint: "Something isn't working as it should.",
        kindSuggestionHint: "Something you'd like to see in the app.",
        kindQuestionHint: "How do I… / Is it possible to…",
        kindPrompt: "Pick one so it reaches the right person.",
        nameLabel: "Your name",
        emailLabel: "Your email",
        emailHelp: "That's where we'll reply.",
        emailPlaceholder: "you@example.com",
        messageLabel: "Your message",
        messagePlaceholder: "What happened? What were you doing just before?",
        optional: "Optional",
        chooseOption: "Choose one",
        chooseDate: "Choose a date",
        clear: "Clear",
        issueRequired: "Required.",
        issueKind: "Choose what it's about.",
        issueEmail: "That doesn't look like an email address.",
        issueShort: "Tell us a little more (3 characters at least).",
        issueLong: "That's over 4,000 characters.",
        issueInvalid: "This value isn't valid.",
        attachmentsHeading: "Images",
        screenshotCaption: "The screen you were on. Cover anything private before sending.",
        screenshotIncluded: "Screenshot attached",
        screenshotExcluded: "Screenshot not attached",
        coverPrivate: "Cover private info",
        screenshotPreview: "Screenshot of the previous screen",
        addPhotos: "Add photos",
        attachmentsCount: "%d of %d",
        removeImage: "Remove image",
        editorHint: "Draw over anything you don't want to send: names, numbers, faces.",
        editorCanvas: "Screenshot. Drag one finger over it to cover parts.",
        toolCover: "Cover",
        toolBox: "Box",
        toolMark: "Point out",
        undo: "Undo",
        cancel: "Cancel",
        done: "Done",
        sentWith: "Sent with your request",
        sentWithDetail: "App and device details help us reproduce the problem. Nothing else is collected.",
        recentActions: "Recent actions",
        send: "Send",
        sending: "Sending…",
        noticeOffline: "Couldn't reach support. Check your connection and try again.",
        noticeRateLimited: "Too many requests in a short time. Please try again later.",
        noticeFailed: "Something went wrong while sending. Please try again.",
        noticeAttachment: "An image couldn't be attached. Try another one.",
        noticeUnavailable: "Support requests aren't available right now.",
        offlineTitle: "You're offline",
        offlineBody: "We need a connection to load the form the first time.",
        retry: "Try again",
        statusConnecting: "Connecting…",
        statusCached: "Saved copy · tap to refresh",
        statusOffline: "Offline",
        successTitle: "Request #%d",
        successDefault: "Got it! We'll reply to the email you left us.",
        successReplies: "Replies go to %@. Mention #%d if you write again.",
        successConfirm: "Our first reply will ask you to confirm that address.",
        sendAnother: "Send another"
    )

    public static let spanish = FaroStrings(
        helpTitle: "Ayuda y comentarios",
        defaultIntro: "Cuéntanos qué pasó. Lo leemos todo y te respondemos por correo.",
        close: "Cerrar",
        kindHeading: "¿De qué se trata?",
        kindProblem: "Algo falla",
        kindSuggestion: "Una idea",
        kindQuestion: "Una pregunta",
        kindProblemHint: "Algo no funciona como debería.",
        kindSuggestionHint: "Algo que te gustaría ver en la app.",
        kindQuestionHint: "Cómo hago… / ¿Se puede…?",
        kindPrompt: "Elige una para que llegue a la persona indicada.",
        nameLabel: "Tu nombre",
        emailLabel: "Tu correo",
        emailHelp: "Ahí te respondemos.",
        emailPlaceholder: "tu@correo.com",
        messageLabel: "Tu mensaje",
        messagePlaceholder: "¿Qué pasó? ¿Qué estabas haciendo justo antes?",
        optional: "Opcional",
        chooseOption: "Elige una opción",
        chooseDate: "Elegir fecha",
        clear: "Borrar",
        issueRequired: "Obligatorio.",
        issueKind: "Elige de qué se trata.",
        issueEmail: "Ese correo no parece válido.",
        issueShort: "Cuéntanos un poco más (mínimo 3 caracteres).",
        issueLong: "Pasa de 4000 caracteres.",
        issueInvalid: "Este valor no es válido.",
        attachmentsHeading: "Imágenes",
        screenshotCaption: "La pantalla en la que estabas. Tapa lo privado antes de enviar.",
        screenshotIncluded: "Captura adjunta",
        screenshotExcluded: "Captura sin adjuntar",
        coverPrivate: "Tapar datos",
        screenshotPreview: "Captura de la pantalla anterior",
        addPhotos: "Añadir fotos",
        attachmentsCount: "%d de %d",
        removeImage: "Quitar imagen",
        editorHint: "Dibuja encima de lo que no quieras enviar: nombres, números, caras.",
        editorCanvas: "Captura. Arrastra un dedo encima para tapar partes.",
        toolCover: "Tapar",
        toolBox: "Recuadro",
        toolMark: "Señalar",
        undo: "Deshacer",
        cancel: "Cancelar",
        done: "Listo",
        sentWith: "Va con tu petición",
        sentWithDetail: "Los datos de la app y del teléfono nos ayudan a reproducir el problema. No se recoge nada más.",
        recentActions: "Últimas acciones",
        send: "Enviar",
        sending: "Enviando…",
        noticeOffline: "No pudimos conectar con soporte. Revisa tu conexión e inténtalo de nuevo.",
        noticeRateLimited: "Demasiados envíos seguidos. Inténtalo más tarde.",
        noticeFailed: "Algo salió mal al enviar. Inténtalo de nuevo.",
        noticeAttachment: "No se pudo adjuntar una imagen. Prueba con otra.",
        noticeUnavailable: "Las peticiones de soporte no están disponibles ahora.",
        offlineTitle: "Sin conexión",
        offlineBody: "La primera vez necesitamos conexión para cargar el formulario.",
        retry: "Reintentar",
        statusConnecting: "Conectando…",
        statusCached: "Copia guardada · toca para actualizar",
        statusOffline: "Sin conexión",
        successTitle: "Petición #%d",
        successDefault: "¡Recibido! Te respondemos al correo que nos dejaste.",
        successReplies: "Te responderemos a %@. Menciona el #%d si vuelves a escribir.",
        successConfirm: "Nuestra primera respuesta te pedirá confirmar ese correo.",
        sendAnother: "Enviar otra"
    )

    public static let portuguese = FaroStrings(
        helpTitle: "Ajuda e comentários",
        defaultIntro: "Conte o que aconteceu. Lemos tudo e respondemos por e-mail.",
        close: "Fechar",
        kindHeading: "Do que se trata?",
        kindProblem: "Algo deu errado",
        kindSuggestion: "Uma ideia",
        kindQuestion: "Uma pergunta",
        kindProblemHint: "Algo não funciona como deveria.",
        kindSuggestionHint: "Algo que você gostaria de ver no app.",
        kindQuestionHint: "Como faço… / É possível…?",
        kindPrompt: "Escolha uma para chegar à pessoa certa.",
        nameLabel: "Seu nome",
        emailLabel: "Seu e-mail",
        emailHelp: "É para lá que responderemos.",
        emailPlaceholder: "voce@exemplo.com",
        messageLabel: "Sua mensagem",
        messagePlaceholder: "O que aconteceu? O que você fazia logo antes?",
        optional: "Opcional",
        chooseOption: "Escolha uma opção",
        chooseDate: "Escolher data",
        clear: "Limpar",
        issueRequired: "Obrigatório.",
        issueKind: "Escolha do que se trata.",
        issueEmail: "Esse e-mail não parece válido.",
        issueShort: "Conte um pouco mais (pelo menos 3 caracteres).",
        issueLong: "Passa de 4.000 caracteres.",
        issueInvalid: "Este valor não é válido.",
        attachmentsHeading: "Imagens",
        screenshotCaption: "A tela em que você estava. Cubra o que for privado antes de enviar.",
        screenshotIncluded: "Captura anexada",
        screenshotExcluded: "Captura não anexada",
        coverPrivate: "Cobrir dados",
        screenshotPreview: "Captura da tela anterior",
        addPhotos: "Adicionar fotos",
        attachmentsCount: "%d de %d",
        removeImage: "Remover imagem",
        editorHint: "Desenhe sobre o que você não quer enviar: nomes, números, rostos.",
        editorCanvas: "Captura. Arraste o dedo por cima para cobrir partes.",
        toolCover: "Cobrir",
        toolBox: "Retângulo",
        toolMark: "Indicar",
        undo: "Desfazer",
        cancel: "Cancelar",
        done: "Concluído",
        sentWith: "Vai com sua solicitação",
        sentWithDetail: "Os dados do app e do aparelho nos ajudam a reproduzir o problema. Nada mais é coletado.",
        recentActions: "Últimas ações",
        send: "Enviar",
        sending: "Enviando…",
        noticeOffline: "Não foi possível conectar ao suporte. Verifique sua conexão e tente de novo.",
        noticeRateLimited: "Muitos envios seguidos. Tente mais tarde.",
        noticeFailed: "Algo deu errado ao enviar. Tente de novo.",
        noticeAttachment: "Não foi possível anexar uma imagem. Tente outra.",
        noticeUnavailable: "As solicitações de suporte não estão disponíveis agora.",
        offlineTitle: "Sem conexão",
        offlineBody: "Na primeira vez precisamos de conexão para carregar o formulário.",
        retry: "Tentar de novo",
        statusConnecting: "Conectando…",
        statusCached: "Cópia salva · toque para atualizar",
        statusOffline: "Sem conexão",
        successTitle: "Solicitação #%d",
        successDefault: "Recebido! Responderemos no e-mail que você deixou.",
        successReplies: "As respostas vão para %@. Mencione o #%d se escrever de novo.",
        successConfirm: "Nossa primeira resposta pedirá para confirmar esse e-mail.",
        sendAnother: "Enviar outra"
    )
}
#endif
