module Raygun

using Colors
using LinearAlgebra
using ProgressBars
using StaticArrays

Vec3 = SVector{3, Float64}
Point3 = SVector{3, Float64}

norm2(vec::Vec3) = dot(vec, vec)
unit_vector(vec::Vec3) = vec/sqrt(norm2(vec))
reflect(v::Vec3, n::Vec3) = v - 2*dot(v,n)*n

@inline function random_unit_vector()
    vec = Vec3(randn(), randn(), randn())
    return unit_vector(vec)
end

struct Ray
    origin::Point3
    direction::Vec3
end

position(ray::Ray, t::Float64) = ray.origin + t*ray.direction

abstract type Hittable end
abstract type Material end

struct HitRecord
    p::Point3
    normal::Vec3
    material::Material
    t::Float64
    front_face::Bool
end

struct Lambertian <: Material
    albedo::Vec3
end
Lambertian(r::Float64, g::Float64, b::Float64) = Lambertian(Vec3(r,g,b))

function scatter(mat::Lambertian, ray::Ray, rec::HitRecord)
    scatter_dir = rec.normal + random_unit_vector()
    scattered = Ray(rec.p, scatter_dir)
    attenuation = mat.albedo
    return (scattered, attenuation)
end


struct Metal <: Material
    albedo::Vec3
    fuzz::Float64
end
Metal(r::Float64, g::Float64, b::Float64, fuzz::Float64) = Metal(Vec3(r,g,b), fuzz)

function scatter(mat::Metal, ray::Ray, rec::HitRecord)
    reflected = reflect(unit_vector(ray.direction), rec.normal)
    scattered = Ray(rec.p, reflected + mat.fuzz*random_unit_vector())
    attenuation = mat.albedo
    return (scattered, attenuation)
end

struct Sphere <: Hittable
    center::Point3
    radius::Float64
    material::Material
end

struct HittableList <: Hittable
    elements::Vector{Hittable}
end

function hit(sphere::Sphere, ray::Ray, tmin::Float64, tmax::Float64)
    oc = ray.origin - sphere.center
    a = norm2(ray.direction)
    half_b = dot(oc, ray.direction)
    c = norm2(oc) - sphere.radius*sphere.radius
    Δ = half_b*half_b - a*c
    if (Δ < 0)
        return nothing
    end

    sqrtd = sqrt(Δ)
    root = (-half_b - sqrtd) / a

    if (root < tmin || root > tmax)
        root = (-half_b + sqrtd) / a
        if (root < tmin || root > tmax)
            return nothing
        end
    end

    t = root
    p = position(ray, t)
    out_normal = (p - sphere.center) / sphere.radius
    front_face = dot(ray.direction, out_normal) < 0
    normal = front_face ? out_normal : -out_normal
    return HitRecord(p, normal, sphere.material, t, front_face)
end

function hit(list::HittableList, ray::Ray, tmin::Float64, tmax::Float64)
    closest_hit = nothing

    for obj in list.elements
        result = hit(obj, ray, tmin, tmax)
        if (result !== nothing) && (closest_hit === nothing || result.t < closest_hit.t)
            closest_hit = result
        end
    end
    return closest_hit
end


function color(ray::Ray, world::Hittable, depth::Int)
    if (depth <= 0)
        return Vec3(0,0,0)
    end

    record = hit(world, ray, 0.001, floatmax(Float64))
    if record !== nothing
        scattered, attenuation = scatter(record.material, ray, record)
        return attenuation .* color(scattered, world, depth-1)
    end

    unit_direction = unit_vector(ray.direction)
    t = 0.5*(unit_direction[2] + 1.0)
    return Vec3(1-0.5t,1-0.3t,1.0)
end

struct Camera
    origin::Point3
    lower_left_corner::Point3
    vertical::Vec3
    horizontal::Vec3
end

function Camera()
    aspect_ratio = 16/9
    viewport_height = 2.0
    viewport_width = viewport_height*aspect_ratio
    focal_length = 1.0

    origin = Point3(0,0,0)
    horizontal = Vec3(viewport_width,0,0)
    vertical = Vec3(0,viewport_height,0)
    lower_left_corner = origin - horizontal/2 - vertical/2 - Vec3(0,0,focal_length)
    return Camera(origin, lower_left_corner, vertical, horizontal)
end

@inline function get_ray(camera::Camera, u::Float64, v::Float64)
    return Ray(
        camera.origin, 
        camera.lower_left_corner + u*camera.horizontal + v*camera.vertical - camera.origin
        )
end

@inline function rgb_color(combined::Vec3, samples_per_pixel::Int)
    corrected = sqrt.(combined/samples_per_pixel)
    return RGB(corrected...)
end

function render(samples_per_pixel=100)
    # image
    aspect_ratio = 16/9
    width = 400
    height = convert(Int, width/aspect_ratio)

    # world
    world = HittableList([
        Sphere(Point3(0,0,-1), 0.5, Lambertian(0.7,0.3,0.3)),
        Sphere(Point3(0,-100.5,-1), 100, Lambertian(0.8,0.8,0.0)),
        Sphere(Point3(-1,0,-1), 0.5, Metal(0.8,0.8,0.8, 0.3)),
        Sphere(Point3(1,0,-1),0.5, Metal(0.8,0.6,0.2, 0.8))
        ])
    
    # camera
    camera = Camera()

    max_depth = 50
    
    img = Array{RGB, 2}(undef, height, width)
    for i in ProgressBar(1:width)
        for j in 1:height
            c = Vec3(0,0,0)
            for s in 1:samples_per_pixel
                u = (i+rand())/width
                v = (height-j+rand())/height
                ray = get_ray(camera, u, v)
                c += color(ray, world, max_depth)
            end
            img[j,i] = rgb_color(c, samples_per_pixel)
        end
    end
    return img
end
end # module
