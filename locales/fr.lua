local Translations = {
    error = {
        you_already_have_objects_down = 'Tu as déjà %{MaxPlantCount} objets posés',
    },
}

if GetConvar('rsg_locale', 'en') == 'fr' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
