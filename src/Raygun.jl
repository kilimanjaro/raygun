module Raygun

using Colors
using LinearAlgebra
using ProgressBars
using StaticArrays

Vec3 = SVector{3, Float64}
Point3 = SVector{3, Float64}

norm2(vec::Vec3) = dot(vec, vec)
unit_vector(vec::Vec3) = vec/sqrt(norm2(vec))

struct Ray
    origin::Point3
    direction::Vec3
end

position(ray::Ray, t::Float64) = ray.origin + t*ray.direction


struct HitRecord
    p::Point3
    normal::Vec3
    t::Float64
    front_face::Bool
end

abstract type Hittable end

struct Sphere <: Hittable
    center::Point3
    radius::Float64
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
    return HitRecord(p, normal, t, front_face)
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


function color(ray::Ray, world::Hittable)
    record = hit(world, ray, 0.0, floatmax(Float64))
    if record !== nothing
        return Vec3(
            (1+record.normal[1])/2, 
            (1+record.normal[2])/2, 
            (1+record.normal[3])/2
        )
    end

    unit_direction = unit_vector(ray.direction)
    t = 0.5*(unit_direction[2] + 1.0)
    return t*Vec3(0.5,0.7,1.0) + (1-t)*Vec3(1.0, 1.0, 1.0)
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

function get_ray(camera::Camera, u::Float64, v::Float64)
    return Ray(
        camera.origin, 
        camera.lower_left_corner + u*camera.horizontal + v*camera.vertical - camera.origin
        )
end

function render()
    # image
    aspect_ratio = 16/9
    width = 400
    height = convert(Int, width/aspect_ratio)
    samples_per_pixel = 100

    # world
    world = HittableList([
        Sphere(Point3(0,0,-1), 0.5),
        Sphere(Point3(0,-100.5,-1), 100)
        ])
    
    # camera
    camera = Camera()

    img = Array{RGB, 2}(undef, height, width)
    for j in ProgressBar(1:height)
        for i in 1:width
            c = Vec3(0,0,0)
            for s in 1:samples_per_pixel
                u = (i+rand())/width
                v = (height-j+rand())/height
                ray = get_ray(camera, u, v)
                c += color(ray, world)
            end
            c /= samples_per_pixel
            img[j,i] = RGB(c[1],c[2],c[3])
        end
    end
    return img
end
end # module
