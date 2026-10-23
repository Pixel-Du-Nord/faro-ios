#if canImport(UIKit) && os(iOS)
import Faro
import Foundation

/**
 FaroUI's own texts in English, Spanish and Portuguese. The form's texts
 (title, labels, options…) come from the Faro panel; these cover what Faro
 does not send: the names of the request kinds, defaults for empty labels,
 errors, notices and buttons.
 */
struct FaroStrings: Sendable {
    let helpTitle: String
    let defaultIntro: String
    let close: String
    let kindHeading: String
    let kindProblem: String
    let kindSuggestion: String
    let kindQuestion: String
    let kindProblemHint: String
    let kindSuggestionHint: String
    let kindQuestionHint: String
    let kindPrompt: String
    let nameLabel: String
    let emailLabel: String
    let emailHelp: String
    let emailPlaceholder: String
    let messageLabel: String
    let messagePlaceholder: String
    let optional: String
    let chooseOption: String
    let chooseDate: String
    let clear: String
    let issueRequired: String
    let issueKind: String
    let issueEmail: String
    let issueShort: String
    let issueLong: String
    let issueInvalid: String
    let attachmentsHeading: String
    let screenshotCaption: String
    let screenshotIncluded: String
    let screenshotExcluded: String
    let coverPrivate: String
    let screenshotPreview: String
    let addPhotos: String
    let attachmentsCount: String
    let removeImage: String
    let editorHint: String
    let editorCanvas: String
    let undo: String
    let cancel: String
    let done: String
    let sentWith: String
    let sentWithDetail: String
    let recentActions: String
    let send: String
    let sending: String
    let noticeOffline: String
    let noticeRateLimited: String
    let noticeFailed: String
    let noticeAttachment: String
    let noticeUnavailable: String
    let offlineTitle: String
    let offlineBody: String
    let retry: String
    let statusConnecting: String
    let statusCached: String
    let statusOffline: String
    let successTitle: String
    let successDefault: String
    let successReplies: String
    let successConfirm: String
    let sendAnother: String

    /// The texts for a language (`"es"`, `"pt-BR"`…); English for anything else.
    static func forLanguage(_ language: String) -> FaroStrings {
        switch FaroLocale.language(language) {
        case "es": return .es
        case "pt": return .pt
        default: return .en
        }
    }

    func kindName(_ kind: FaroKind) -> String {
        switch kind {
        case .problem: return kindProblem
        case .suggestion: return kindSuggestion
        case .question: return kindQuestion
        default: return kind.rawValue.capitalized
        }
    }

    func kindHint(_ kind: FaroKind) -> String {
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

    static let en = FaroStrings(
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
        editorHint: "Draw over anything you'd rather not send.",
        editorCanvas: "Screenshot. Drag one finger to cover parts of it.",
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

    static let es = FaroStrings(
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
        editorHint: "Dibuja encima de lo que no quieras enviar.",
        editorCanvas: "Captura. Arrastra un dedo para tapar partes.",
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

    static let pt = FaroStrings(
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
        editorHint: "Desenhe sobre o que você não quiser enviar.",
        editorCanvas: "Captura. Arraste um dedo para cobrir partes.",
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
