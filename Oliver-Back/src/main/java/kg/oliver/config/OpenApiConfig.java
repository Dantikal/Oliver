package kg.oliver.config;

import io.swagger.v3.oas.models.*;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.*;
import io.swagger.v3.oas.models.media.*;
import io.swagger.v3.oas.models.responses.ApiResponse;
import kg.oliver.api.Responses;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.*;
import java.util.Map;

@Configuration
public class OpenApiConfig {
    @Bean
    OpenAPI api() {
        return new OpenAPI()
                .info(new Info().title("Oliver Marketplace API").version("1.0")
                        .description("Кыргызстан. REST + STOMP /ws. Media references use mediaId returned by /media/upload."))
                .components(new Components().addSecuritySchemes("bearerAuth", new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP).scheme("bearer").bearerFormat("JWT")))
                .addSecurityItem(new SecurityRequirement().addList("bearerAuth"));
    }

    @Bean
    OpenApiCustomizer errorResponses() {
        return api -> {
            var schemas = io.swagger.v3.core.converter.ModelConverters.getInstance().read(Responses.Error.class);
            schemas.forEach(api.getComponents()::addSchemas);
            var descriptions = Map.of("400", "Ошибка валидации", "401", "Требуется авторизация",
                    "403", "Доступ запрещён", "404", "Объект не найден", "409", "Конфликт данных",
                    "429", "Слишком много запросов", "500", "Ошибка сервера", "503", "Сервис недоступен");
            api.getPaths().values().forEach(path -> path.readOperations().forEach(operation -> descriptions.forEach((status, description) -> operation.getResponses().addApiResponse(status,
                            new ApiResponse().description(description).content(new Content()
                                    .addMediaType("application/json", new MediaType()
                                            .schema(new Schema<>().$ref("#/components/schemas/Error"))))))));
        };
    }
}
